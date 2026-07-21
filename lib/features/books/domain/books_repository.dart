class BookItem {
  const BookItem({
    required this.id,
    required this.name,
    this.sku = '',
    this.rate = 0,
    this.type = 'Goods',
    this.unit = 'pcs',
    this.hsnCode = '',
    this.taxRate = 18,
    this.costPrice = 0,
    this.trackInventory = false,
    this.stockOnHand = 0,
  });
  final int id;
  final String name;
  final String sku;
  final double rate;
  final String type, unit, hsnCode;
  final double taxRate, costPrice, stockOnHand;
  final bool trackInventory;
}

class ItemHistoryEntry {
  const ItemHistoryEntry({required this.date, required this.details});

  final DateTime date;
  final String details;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.company = '',
    this.email = '',
    this.phone = '',
    this.gstTreatment = 'Registered Business - Regular',
    this.receivables = 0,
  });
  final int id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String gstTreatment;
  final double receivables;
}

enum TransactionType { quote, salesOrder, invoice }

class SalesTransaction {
  const SalesTransaction({
    required this.id,
    required this.type,
    required this.number,
    required this.customer,
    required this.date,
    this.amount = 0,
    this.status = 'DRAFT',
    this.referenceNumber = '',
    this.dueDate,
    this.notes = '',
    this.terms = '',
  });
  final int id;
  final TransactionType type;
  final String number;
  final String customer;
  final DateTime date;
  final double amount;
  final String status;
  final String referenceNumber;
  final DateTime? dueDate;
  final String notes;
  final String terms;
}

class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.customer,
    required this.number,
    required this.date,
    required this.amount,
    this.customerId,
    this.dueDate,
    this.referenceNumber = '',
    this.discount = 0,
    this.taxAmount = 0,
    this.amountPaid = 0,
    this.notes = '',
    this.terms = '',
    this.paymentTerms = '',
    this.discountType = '%',
    this.items = const [],
  });
  final TransactionType type;
  final String customer;
  final String number;
  final DateTime date;
  final double amount;
  final int? customerId;
  final DateTime? dueDate;
  final String referenceNumber, notes, terms;
  final String paymentTerms, discountType;
  final double discount, taxAmount, amountPaid;
  final List<InvoiceLineDraft> items;
}

class InvoiceLineDraft {
  const InvoiceLineDraft({required this.name, this.description = '', required this.quantity, required this.rate, this.tax = 'No Tax'});
  final String name, description, tax;
  final double quantity, rate;
}

class InventoryAdjustment {
  const InventoryAdjustment({
    required this.id,
    required this.date,
    required this.reason,
    required this.referenceNumber,
    required this.type,
    required this.status,
    this.description = '',
  });
  final int id;
  final DateTime date;
  final String reason, referenceNumber, type, status, description;
}

class AdjustmentDraft {
  const AdjustmentDraft({
    required this.itemId,
    required this.quantityAdjusted,
    required this.reason,
    required this.referenceNumber,
    this.description = '',
    this.applyNow = true,
  });
  final int itemId;
  final double quantityAdjusted;
  final String reason, referenceNumber, description;
  final bool applyNow;
}

class StockEntryDraft {
  const StockEntryDraft({
    required this.grnNumber,
    required this.supplier,
    required this.poNumber,
    required this.poDate,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.materialCode,
    required this.description,
    required this.heatNumber,
    required this.batchNumber,
    required this.quantity,
    required this.weight,
    required this.inspectionStatus,
    required this.storeLocation,
  });

  final String grnNumber, supplier, poNumber, invoiceNumber, materialCode;
  final String description;
  final String heatNumber, batchNumber, inspectionStatus, storeLocation;
  final DateTime poDate, invoiceDate;
  final double quantity, weight;
}

class MaterialDraft {
  const MaterialDraft({
    required this.sourceType,
    required this.code,
    required this.description,
    required this.materialType,
    required this.grade,
    required this.make,
    required this.model,
    required this.size,
    required this.unit,
    required this.density,
    required this.supplier,
    required this.heatNumber,
    required this.batchNumber,
    required this.warehouseLocation,
    required this.rackLocation,
    required this.minimumStock,
    required this.maximumStock,
    required this.reorderLevel,
  });

  final String sourceType, code, description, materialType, grade, make, model;
  final String size, unit, density, supplier, heatNumber, batchNumber;
  final String warehouseLocation, rackLocation;
  final String minimumStock, maximumStock, reorderLevel;
}

class MoveStockDraft {
  const MoveStockDraft({
    required this.workOrder,
    required this.productionOrder,
    required this.jobCard,
    required this.date,
    required this.machine,
    required this.operatorName,
    required this.captureWorkOrder,
    required this.materialId,
    required this.quantityIssued,
    required this.weightIssued,
    required this.issuedBy,
    required this.receivedBy,
  });

  final String workOrder, productionOrder, jobCard;
  final DateTime date;
  final String machine, operatorName, captureWorkOrder;
  final int materialId;
  final double quantityIssued, weightIssued;
  final String issuedBy, receivedBy;
}

class MaterialRequestDraft {
  const MaterialRequestDraft({
    required this.date,
    required this.machine,
    required this.operatorName,
    required this.workOrder,
    required this.material,
    required this.quantityIssued,
    required this.weightIssued,
  });

  final DateTime date;
  final String machine, operatorName, workOrder, material;
  final double quantityIssued, weightIssued;
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.receivables,
    required this.payables,
    required this.revenue,
    required this.netProfit,
    required this.inventoryAtRisk,
  });
  final double receivables, payables, revenue, netProfit;
  final int inventoryAtRisk;
  double get currentReceivables => receivables * .9;
  double get overdueReceivables => receivables * .1;
  double get currentPayables => payables * .85;
  double get overduePayables => payables * .15;
}

abstract interface class BooksRepository {
  Future<List<BookItem>> getItems();
  Future<List<ItemHistoryEntry>> getItemHistory(int itemId);
  Future<void> addItem({
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Goods',
  });
  Future<List<Customer>> getCustomers();
  Future<void> addCustomer({
    required String name,
    String company = '',
    String phone = '',
  });
  Future<List<SalesTransaction>> getTransactions(TransactionType type);
  Future<void> addTransaction(TransactionDraft draft);
  Future<List<InventoryAdjustment>> getAdjustments();
  Future<void> addAdjustment(AdjustmentDraft draft);
  Future<void> addStock(StockEntryDraft draft);
  Future<void> addMaterial(MaterialDraft draft);
  Future<void> moveStock(MoveStockDraft draft);
  Future<void> requestMaterial(MaterialRequestDraft draft);
  Future<DashboardMetrics> getDashboardMetrics();
  Future<void> recordInvoicePaid(int invoiceId);
  Future<void> convertQuote(int quoteId, TransactionType targetType);
}
