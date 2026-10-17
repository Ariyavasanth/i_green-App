import 'package:flutter/foundation.dart';

import '../../employee/data/firebase_employee_repository.dart';
import '../../employee/domain/employee_repository.dart';
import '../../organization/data/firebase_organization_repository.dart';
import '../../organization/domain/designation.dart';
import '../../organization/domain/organization_band.dart';
import '../../organization/domain/organization_repository.dart';
import '../domain/hierarchy_node.dart';
import '../domain/hierarchy_repository.dart';
import '../domain/hierarchy_tree.dart';

/// Firebase and domain repository implementation for the Hierarchy module.
class FirebaseHierarchyRepository implements HierarchyRepository {
  final EmployeeRepository _employeeRepository;
  final OrganizationRepository _organizationRepository;

  FirebaseHierarchyRepository({
    EmployeeRepository? employeeRepository,
    OrganizationRepository? organizationRepository,
  }) : _employeeRepository = employeeRepository ?? FirebaseEmployeeRepository(),
       _organizationRepository =
           organizationRepository ?? FirebaseOrganizationRepository();

  @override
  Future<HierarchyTree> getHierarchyTree({
    String? organizationId,
    String? organizationName,
  }) async {
    try {
      // 1. Fetch all active employees
      final allEmployees = await _employeeRepository.getEmployees();

      // 2. Filter employees by organization if provided
      final hasOrgId =
          organizationId != null &&
          organizationId.isNotEmpty &&
          organizationId != 'All';
      final hasOrgName =
          organizationName != null &&
          organizationName.isNotEmpty &&
          organizationName != 'All';

      final orgEmployees = allEmployees.where((e) {
        // Exclude archived, deleted, or draft records
        final s = e.status.trim().toLowerCase();
        if (s == 'archived' || s == 'deleted' || s == 'draft') return false;

        if (hasOrgId) {
          final eOrgId = e.organizationId.trim();
          if (eOrgId.isNotEmpty && eOrgId == organizationId.trim()) return true;
        }
        if (hasOrgName) {
          final eOrgName = e.organizationName.trim().toLowerCase();
          if (eOrgName.isNotEmpty &&
              eOrgName == organizationName.trim().toLowerCase()) {
            return true;
          }
        }
        // If neither filter is specified, include all
        return !hasOrgId && !hasOrgName;
      }).toList();

      if (orgEmployees.isEmpty) {
        return HierarchyTree(
          organizationId: organizationId ?? '',
          organizationName: organizationName ?? '',
          rootNodes: const [],
          totalEmployees: 0,
          departmentsCount: 0,
        );
      }

      // Determine effective organization identifiers
      final effectiveOrgId = organizationId ??
          orgEmployees.firstWhere((e) => e.organizationId.isNotEmpty, orElse: () => orgEmployees.first).organizationId;
      final effectiveOrgName = organizationName ??
          orgEmployees.firstWhere((e) => e.organizationName.isNotEmpty, orElse: () => orgEmployees.first).organizationName;

      // 3. Fetch designations and bands for the organization
      final designations = await _organizationRepository.getDesignations(
        organizationId: effectiveOrgId.isNotEmpty ? effectiveOrgId : null,
        organizationName: effectiveOrgName.isNotEmpty ? effectiveOrgName : null,
      );

      final bands = await _organizationRepository.getBands(
        organizationId: effectiveOrgId.isNotEmpty ? effectiveOrgId : null,
        organizationName: effectiveOrgName.isNotEmpty ? effectiveOrgName : null,
      );

      // Build designation lookup maps:
      // Primary: department + designation (exact pair)
      // Fallback: designation name only
      final desigPairMap = <String, Designation>{};
      final desigNameMap = <String, Designation>{};
      for (final d in designations) {
        final dName = d.designationName.trim().toLowerCase();
        final deptName = d.departmentName.trim().toLowerCase();
        if (dName.isNotEmpty) {
          desigPairMap['$deptName|$dName'] = d;
          desigNameMap.putIfAbsent(dName, () => d);
        }
      }

      // Build band lookup maps:
      final bandByIdMap = <String, OrganizationBand>{};
      final bandByLevelMap = <int, OrganizationBand>{};
      for (final b in bands) {
        bandByIdMap[b.id] = b;
        bandByLevelMap[b.level] = b;
      }

      // 4. Create a HierarchyNode for each employee with resolved Band info
      final nodeMap = <String, HierarchyNode>{};
      final nodesList = <HierarchyNode>[];
      final departmentsSet = <String>{};

      for (final emp in orgEmployees) {
        if (emp.department.trim().isNotEmpty) {
          departmentsSet.add(emp.department.trim());
        }

        final desigClean = emp.designation.trim().toLowerCase();
        final deptClean = emp.department.trim().toLowerCase();

        // Resolve Designation
        final matchedDesig = desigPairMap['$deptClean|$desigClean'] ??
            desigNameMap[desigClean];

        int resolvedLevel = matchedDesig?.bandLevel ?? 0;
        String resolvedCode = matchedDesig?.bandCode ?? '';
        String resolvedTitle = '';
        int? resolvedColorHex;

        if (matchedDesig != null && matchedDesig.bandId.isNotEmpty) {
          final matchedBand = bandByIdMap[matchedDesig.bandId] ??
              bandByLevelMap[matchedDesig.bandLevel];
          if (matchedBand != null) {
            resolvedLevel = matchedBand.level;
            resolvedCode = matchedBand.bandCode.isNotEmpty
                ? matchedBand.bandCode
                : 'Band ${matchedBand.level}';
            resolvedTitle = matchedBand.title;
            resolvedColorHex = matchedBand.colorHex;
          }
        } else if (resolvedLevel > 0 && bandByLevelMap.containsKey(resolvedLevel)) {
          final matchedBand = bandByLevelMap[resolvedLevel]!;
          resolvedCode = matchedBand.bandCode.isNotEmpty
              ? matchedBand.bandCode
              : 'Band $resolvedLevel';
          resolvedTitle = matchedBand.title;
          resolvedColorHex = matchedBand.colorHex;
        }

        if (resolvedTitle.isEmpty && resolvedLevel > 0) {
          resolvedTitle = _defaultBandTitleForLevel(resolvedLevel);
        }

        final node = HierarchyNode(
          employee: emp,
          bandLevel: resolvedLevel,
          bandCode: resolvedCode.isNotEmpty
              ? resolvedCode
              : (resolvedLevel > 0 ? 'Band $resolvedLevel' : ''),
          bandTitle: resolvedTitle,
          bandColorHex: resolvedColorHex,
        );

        nodesList.add(node);

        // Index the node by multiple keys for reliable manager lookup
        if (emp.employeeId.trim().isNotEmpty) {
          nodeMap[emp.employeeId.trim().toLowerCase()] = node;
        }
        if (emp.id != 0) {
          nodeMap[emp.id.toString()] = node;
        }
        if (emp.emailAddress.trim().isNotEmpty) {
          nodeMap[emp.emailAddress.trim().toLowerCase()] = node;
        }
      }

      // 5. Build Parent-Child Relationships with Cycle Detection
      final childEmployeeIds = <String>{};
      bool hasCycles = false;
      bool hasMissingManagers = false;

      for (final node in nodesList) {
        final mgrId = node.employee.reportingManagerId.trim();

        if (mgrId.isEmpty) {
          // Employee has no manager -> potential root
          continue;
        }

        final parentNode = nodeMap[mgrId.toLowerCase()];

        if (parentNode == null) {
          // Manager ID is set but not found among active employees in this organization
          hasMissingManagers = true;
          // Mark the node so UI can flag it
          final updated = node.copyWith(
            isMissingManager: true,
            missingManagerId: mgrId,
            missingManagerName: node.employee.reportingManager.trim().isNotEmpty
                ? node.employee.reportingManager.trim()
                : null,
          );
          // Replace in nodesList and nodeMap
          final idx = nodesList.indexOf(node);
          if (idx != -1) nodesList[idx] = updated;
          if (updated.employee.employeeId.trim().isNotEmpty) {
            nodeMap[updated.employee.employeeId.trim().toLowerCase()] = updated;
          }
          // Treated as root candidate so it is never hidden
          continue;
        }

        // Cycle Detection: Check if adding 'node' under 'parentNode' would create a loop
        // Traverse upwards from parentNode. If 'node' is an ancestor of 'parentNode', cycle exists!
        bool isCycle = false;
        HierarchyNode? current = parentNode;
        final visitedInTraversal = <String>{
          node.employee.employeeId.trim().toLowerCase()
        };

        while (current != null) {
          final curId = current.employee.employeeId.trim().toLowerCase();
          if (curId.isNotEmpty && visitedInTraversal.contains(curId)) {
            isCycle = true;
            break;
          }
          if (curId.isNotEmpty) {
            visitedInTraversal.add(curId);
          }
          final upMgrId = current.employee.reportingManagerId.trim();
          current = upMgrId.isNotEmpty ? nodeMap[upMgrId.toLowerCase()] : null;
        }

        if (isCycle) {
          hasCycles = true;
          final updated = node.copyWith(hasCycle: true);
          final idx = nodesList.indexOf(node);
          if (idx != -1) nodesList[idx] = updated;
          if (updated.employee.employeeId.trim().isNotEmpty) {
            nodeMap[updated.employee.employeeId.trim().toLowerCase()] = updated;
          }
          // Do NOT link under parent to prevent infinite loops!
          continue;
        }

        // Valid relationship: Link node as child of parent
        parentNode.children.add(node);
        childEmployeeIds.add(node.employee.employeeId.trim().toLowerCase());
      }

      // 6. Collect root nodes (nodes that are NOT children of any other node)
      final rootNodes = <HierarchyNode>[];
      for (final node in nodesList) {
        final empIdKey = node.employee.employeeId.trim().toLowerCase();
        if (!childEmployeeIds.contains(empIdKey)) {
          rootNodes.add(node);
        }
      }

      // 7. Sort nodes deterministically:
      // Roots: Highest band level first (Band 7 at top), then alphabetical
      rootNodes.sort((a, b) {
        if (a.bandLevel != b.bandLevel) {
          return b.bandLevel.compareTo(a.bandLevel);
        }
        return a.employee.fullName.toLowerCase().compareTo(b.employee.fullName.toLowerCase());
      });

      // Recursively sort children and assign depth
      int maxDepth = 0;
      void processNode(HierarchyNode n, int depth) {
        n.depth = depth;
        if (depth > maxDepth) maxDepth = depth;

        n.children.sort((a, b) {
          if (a.bandLevel != b.bandLevel) {
            return b.bandLevel.compareTo(a.bandLevel);
          }
          return a.employee.fullName.toLowerCase().compareTo(b.employee.fullName.toLowerCase());
        });

        for (final child in n.children) {
          processNode(child, depth + 1);
        }
      }

      for (final root in rootNodes) {
        processNode(root, 0);
      }

      return HierarchyTree(
        organizationId: effectiveOrgId,
        organizationName: effectiveOrgName,
        rootNodes: rootNodes,
        totalEmployees: orgEmployees.length,
        departmentsCount: departmentsSet.length,
        maxDepth: maxDepth,
        hasCycles: hasCycles,
        hasMissingManagers: hasMissingManagers,
      );
    } catch (e, stack) {
      debugPrint('[FirebaseHierarchyRepository] Error building hierarchy tree: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<List<HierarchyNode>> getReportingChain(
    String employeeId, {
    String? organizationId,
    String? organizationName,
  }) async {
    final tree = await getHierarchyTree(
      organizationId: organizationId,
      organizationName: organizationName,
    );

    final targetNode = tree.findNode(employeeId);
    if (targetNode == null) return const [];

    // Traverse upwards from target to the root
    final allNodes = tree.allNodes;
    final nodeById = <String, HierarchyNode>{};
    for (final n in allNodes) {
      if (n.employee.employeeId.trim().isNotEmpty) {
        nodeById[n.employee.employeeId.trim().toLowerCase()] = n;
      }
      if (n.employee.id != 0) {
        nodeById[n.employee.id.toString()] = n;
      }
    }

    final chain = <HierarchyNode>[targetNode];
    final visited = <String>{
      targetNode.employee.employeeId.trim().toLowerCase()
    };

    var current = targetNode;
    while (true) {
      final mgrId = current.employee.reportingManagerId.trim().toLowerCase();
      if (mgrId.isEmpty) break;

      final parent = nodeById[mgrId];
      if (parent == null) break;

      final pId = parent.employee.employeeId.trim().toLowerCase();
      if (visited.contains(pId)) {
        // Cycle detected, break upwards traversal
        break;
      }
      visited.add(pId);
      chain.add(parent);
      current = parent;
    }

    // Return linear chain from employee up to highest authority
    return chain;
  }

  @override
  Future<List<HierarchyNode>> getDirectReports(
    String employeeId, {
    String? organizationId,
    String? organizationName,
  }) async {
    final tree = await getHierarchyTree(
      organizationId: organizationId,
      organizationName: organizationName,
    );

    final targetNode = tree.findNode(employeeId);
    return targetNode?.children ?? const [];
  }

  static String _defaultBandTitleForLevel(int level) {
    switch (level) {
      case 7:
        return 'Top Leadership (C-Suite / MD)';
      case 6:
        return 'Senior Leadership (Director / VP)';
      case 5:
        return 'Senior Management (Lead / HOD)';
      case 4:
        return 'Middle Management (Manager)';
      case 3:
        return 'Senior Professional (Senior)';
      case 2:
        return 'Operational Associate (Officer)';
      case 1:
        return 'Entry Level (Associate / Trainee)';
      default:
        return '';
    }
  }
}
