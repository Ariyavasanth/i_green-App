import 'package:flutter/material.dart';

class FundCategoryDefinition {
  final String title;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<FundSubCategoryDefinition> subCategories;

  const FundCategoryDefinition({
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.subCategories,
  });
}

class FundSubCategoryDefinition {
  final String title;
  final IconData icon;
  final String? assetPath;

  const FundSubCategoryDefinition({
    required this.title,
    required this.icon,
    this.assetPath,
  });
}

class FundCategoryConstants {
  static const List<FundCategoryDefinition> categories = [
    // 1. Fuel
    FundCategoryDefinition(
      title: 'Fuel',
      icon: Icons.local_gas_station_rounded,
      primaryColor: Color(0xFFEF4444),
      secondaryColor: Color(0xFFFEE2E2),
      subCategories: [
        FundSubCategoryDefinition(title: 'CNG', icon: Icons.speed_rounded),
        FundSubCategoryDefinition(title: 'Petrol', icon: Icons.local_gas_station_outlined),
        FundSubCategoryDefinition(title: 'Diesel', icon: Icons.local_shipping_rounded),
        FundSubCategoryDefinition(title: 'Electricity', icon: Icons.electric_bolt_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 2. Rental
    FundCategoryDefinition(
      title: 'Rental',
      icon: Icons.car_rental_rounded,
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFFEDE9FE),
      subCategories: [
        FundSubCategoryDefinition(title: 'Truck', icon: Icons.fire_truck_rounded),
        FundSubCategoryDefinition(title: 'Drencher', icon: Icons.water_drop_rounded),
        FundSubCategoryDefinition(title: 'Earth', icon: Icons.landscape_rounded),
        FundSubCategoryDefinition(title: 'Hydra', icon: Icons.precision_manufacturing_rounded),
        FundSubCategoryDefinition(title: 'Suction Trunk', icon: Icons.airport_shuttle_rounded),
        FundSubCategoryDefinition(title: 'Truck Filling Equipment', icon: Icons.oil_barrel_rounded),
        FundSubCategoryDefinition(title: 'WINCH Motor', icon: Icons.settings_suggest_rounded),
        FundSubCategoryDefinition(title: 'Generator Set', icon: Icons.power_rounded),
        FundSubCategoryDefinition(title: 'Apple', icon: Icons.devices_other_rounded),
        FundSubCategoryDefinition(title: 'Water Tanker', icon: Icons.water_damage_rounded),
        FundSubCategoryDefinition(title: 'HDD Mission', icon: Icons.hardware_rounded),
        FundSubCategoryDefinition(title: 'Jackhammer', icon: Icons.construction_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 3. Travel
    FundCategoryDefinition(
      title: 'Travel',
      icon: Icons.flight_takeoff_rounded,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFFE0F2FE),
      subCategories: [
        FundSubCategoryDefinition(title: 'Bus', icon: Icons.directions_bus_rounded),
        FundSubCategoryDefinition(title: 'Rail', icon: Icons.train_rounded),
        FundSubCategoryDefinition(title: 'Airway', icon: Icons.flight_rounded),
        FundSubCategoryDefinition(title: 'Seaway', icon: Icons.directions_boat_rounded),
        FundSubCategoryDefinition(title: 'Car', icon: Icons.directions_car_rounded),
        FundSubCategoryDefinition(title: 'Van', icon: Icons.airport_shuttle_rounded),
        FundSubCategoryDefinition(title: '2 Wheeler', icon: Icons.two_wheeler_rounded),
        FundSubCategoryDefinition(title: '3 Wheeler', icon: Icons.electric_rickshaw_rounded),
        FundSubCategoryDefinition(title: 'Travel Tester', icon: Icons.person_search_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 4. Transport
    FundCategoryDefinition(
      title: 'Transport',
      icon: Icons.local_shipping_rounded,
      primaryColor: Color(0xFF0D9488),
      secondaryColor: Color(0xFFCCFBF1),
      subCategories: [
        FundSubCategoryDefinition(title: 'Bus', icon: Icons.directions_bus_filled_rounded),
        FundSubCategoryDefinition(title: 'Rail', icon: Icons.directions_transit_rounded),
        FundSubCategoryDefinition(title: 'Airways', icon: Icons.airplanemode_active_rounded),
        FundSubCategoryDefinition(title: 'Seaway', icon: Icons.sailing_rounded),
        FundSubCategoryDefinition(title: '2 Wheeler', icon: Icons.two_wheeler_rounded),
        FundSubCategoryDefinition(title: '3 Wheeler', icon: Icons.electric_rickshaw_rounded),
        FundSubCategoryDefinition(title: 'Truck', icon: Icons.local_shipping_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 5. Accommodation
    FundCategoryDefinition(
      title: 'Accommodation',
      icon: Icons.hotel_rounded,
      primaryColor: Color(0xFF6366F1),
      secondaryColor: Color(0xFFE0E7FF),
      subCategories: [
        FundSubCategoryDefinition(title: 'Large House', icon: Icons.holiday_village_rounded),
        FundSubCategoryDefinition(title: 'Hotel', icon: Icons.hotel_rounded),
        FundSubCategoryDefinition(title: 'Resort', icon: Icons.beach_access_rounded),
        FundSubCategoryDefinition(title: 'PG', icon: Icons.bed_rounded),
        FundSubCategoryDefinition(title: 'Hostel', icon: Icons.apartment_rounded),
        FundSubCategoryDefinition(title: 'Land', icon: Icons.terrain_rounded),
        FundSubCategoryDefinition(title: 'Guesthouse', icon: Icons.night_shelter_rounded),
        FundSubCategoryDefinition(title: 'Office', icon: Icons.business_rounded),
        FundSubCategoryDefinition(title: 'Factory', icon: Icons.factory_rounded),
        FundSubCategoryDefinition(title: 'Factory Labor', icon: Icons.engineering_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 6. Food
    FundCategoryDefinition(
      title: 'Food',
      icon: Icons.restaurant_rounded,
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFFEF3C7),
      subCategories: [
        FundSubCategoryDefinition(title: 'Tea', icon: Icons.coffee_rounded),
        FundSubCategoryDefinition(title: 'Breakfast', icon: Icons.free_breakfast_rounded),
        FundSubCategoryDefinition(title: 'Lunch', icon: Icons.lunch_dining_rounded),
        FundSubCategoryDefinition(title: 'Snacks', icon: Icons.bakery_dining_rounded),
        FundSubCategoryDefinition(title: 'Dinner', icon: Icons.dinner_dining_rounded),
        FundSubCategoryDefinition(title: 'Labor Food', icon: Icons.groups_rounded),
        FundSubCategoryDefinition(title: 'Client Food', icon: Icons.handshake_rounded),
        FundSubCategoryDefinition(title: 'Water Can', icon: Icons.water_damage_rounded),
        FundSubCategoryDefinition(title: 'Water Bottle', icon: Icons.water_drop_rounded),
        FundSubCategoryDefinition(title: 'Midnight Food', icon: Icons.nightlight_round),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 7. Repairs
    FundCategoryDefinition(
      title: 'Repairs',
      icon: Icons.handyman_rounded,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFFE0F2FE),
      subCategories: [
        FundSubCategoryDefinition(title: 'Factory', icon: Icons.factory_rounded),
        FundSubCategoryDefinition(title: 'Site', icon: Icons.construction_rounded),
        FundSubCategoryDefinition(title: 'Office', icon: Icons.business_center_rounded),
        FundSubCategoryDefinition(title: 'Machines', icon: Icons.precision_manufacturing_rounded),
        FundSubCategoryDefinition(title: 'Vehicles', icon: Icons.directions_car_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 8. General
    FundCategoryDefinition(
      title: 'General',
      icon: Icons.account_balance_wallet_rounded,
      primaryColor: Color(0xFFEAB308),
      secondaryColor: Color(0xFFFEF9C3),
      subCategories: [
        FundSubCategoryDefinition(title: 'Pooja', icon: Icons.celebration_rounded),
        FundSubCategoryDefinition(title: 'Printing Expenses', icon: Icons.print_rounded),
        FundSubCategoryDefinition(title: 'Stationary', icon: Icons.draw_rounded),
        FundSubCategoryDefinition(title: 'Gift', icon: Icons.card_giftcard_rounded),
        FundSubCategoryDefinition(title: 'Staff Welfare', icon: Icons.volunteer_activism_rounded),
        FundSubCategoryDefinition(title: 'Team Outing', icon: Icons.groups_rounded),
        FundSubCategoryDefinition(title: 'Insurance', icon: Icons.health_and_safety_rounded),
        FundSubCategoryDefinition(title: 'Medical Expenses', icon: Icons.medical_services_rounded),
        FundSubCategoryDefinition(title: 'Loan or Advance', icon: Icons.currency_exchange_rounded),
        FundSubCategoryDefinition(title: 'Dress Code', icon: Icons.checkroom_rounded),
        FundSubCategoryDefinition(title: 'Safety Equipment', icon: Icons.security_rounded),
        FundSubCategoryDefinition(title: 'Freight and Courier', icon: Icons.markunread_mailbox_rounded),
        FundSubCategoryDefinition(title: 'Professional Consultancy Charges', icon: Icons.support_agent_rounded),
        FundSubCategoryDefinition(title: 'Development Charges', icon: Icons.trending_up_rounded),
        FundSubCategoryDefinition(title: 'Tax', icon: Icons.receipt_long_rounded),
        FundSubCategoryDefinition(title: 'Cleaning Charges', icon: Icons.cleaning_services_rounded),
        FundSubCategoryDefinition(title: 'Renovation Expenses', icon: Icons.home_repair_service_rounded),
        FundSubCategoryDefinition(title: 'Painting Expenses', icon: Icons.format_paint_rounded),
        FundSubCategoryDefinition(title: 'Groceries', icon: Icons.shopping_basket_rounded),
        FundSubCategoryDefinition(title: 'Gas', icon: Icons.propane_tank_rounded),
        FundSubCategoryDefinition(title: 'Refining / Refilling', icon: Icons.autorenew_rounded),
        FundSubCategoryDefinition(title: 'Toiletry Items', icon: Icons.soap_rounded),
        FundSubCategoryDefinition(title: 'Gardening Expenses', icon: Icons.yard_rounded),
        FundSubCategoryDefinition(title: 'Batteries', icon: Icons.battery_charging_full_rounded),
        FundSubCategoryDefinition(title: 'Electrical Items', icon: Icons.electrical_services_rounded),
        FundSubCategoryDefinition(title: 'Watering', icon: Icons.water_drop_rounded),
        FundSubCategoryDefinition(title: 'Refilling Water Bottles', icon: Icons.water_rounded),
        FundSubCategoryDefinition(title: 'Telecommunication Expenses', icon: Icons.phone_in_talk_rounded),
        FundSubCategoryDefinition(title: 'RTOP', icon: Icons.traffic_rounded),
        FundSubCategoryDefinition(title: 'Brokerage or Commissions', icon: Icons.monetization_on_rounded),
        FundSubCategoryDefinition(title: 'Bank Charges', icon: Icons.account_balance_rounded),
        FundSubCategoryDefinition(title: 'Donation', icon: Icons.favorite_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 9. Wages
    FundCategoryDefinition(
      title: 'Wages',
      icon: Icons.payments_rounded,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFFD1FAE5),
      subCategories: [
        FundSubCategoryDefinition(title: 'Betta', icon: Icons.paid_rounded),
        FundSubCategoryDefinition(title: 'Wages', icon: Icons.account_balance_wallet_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 10. Purchase
    FundCategoryDefinition(
      title: 'Purchase',
      icon: Icons.shopping_bag_rounded,
      primaryColor: Color(0xFF414A51),
      secondaryColor: Color(0xFFF1F5F9),
      subCategories: [
        FundSubCategoryDefinition(title: 'Consumed', icon: Icons.inventory_2_rounded),
        FundSubCategoryDefinition(title: 'Repair or Maintenance', icon: Icons.build_circle_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 11. Utilization
    FundCategoryDefinition(
      title: 'Utilization',
      icon: Icons.offline_bolt_rounded,
      primaryColor: Color(0xFFF97316),
      secondaryColor: Color(0xFFFFEDD5),
      subCategories: [
        FundSubCategoryDefinition(title: 'Pipe', icon: Icons.linear_scale_rounded),
        FundSubCategoryDefinition(title: 'Bentonite', icon: Icons.layers_rounded),
        FundSubCategoryDefinition(title: 'Cables', icon: Icons.cable_rounded),
        FundSubCategoryDefinition(title: 'Joint Kits', icon: Icons.extension_rounded),
        FundSubCategoryDefinition(title: 'OD Kits', icon: Icons.cases_rounded),
        FundSubCategoryDefinition(title: 'Water Tanker', icon: Icons.water_damage_rounded),
        FundSubCategoryDefinition(title: 'Safety Shoe', icon: Icons.snowshoeing_rounded),
        FundSubCategoryDefinition(title: 'Helmet', icon: Icons.security_rounded),
        FundSubCategoryDefinition(title: 'Jacket', icon: Icons.checkroom_rounded),
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),

    // 12. Others
    FundCategoryDefinition(
      title: 'Others',
      icon: Icons.more_horiz_rounded,
      primaryColor: Color(0xFF64748B),
      secondaryColor: Color(0xFFF1F5F9),
      subCategories: [
        FundSubCategoryDefinition(title: 'Others', icon: Icons.more_horiz_rounded),
      ],
    ),
  ];

  static List<String> get categoryTitles => categories.map((c) => c.title).toList();

  static IconData getCategoryIcon(String categoryTitle) {
    final cat = categories.where((c) => c.title.toLowerCase() == categoryTitle.toLowerCase()).firstOrNull;
    return cat?.icon ?? Icons.category_rounded;
  }

  static IconData getSubCategoryIcon(String categoryTitle, String subCategoryTitle) {
    final cat = categories.where((c) => c.title.toLowerCase() == categoryTitle.toLowerCase()).firstOrNull;
    if (cat != null) {
      final sub = cat.subCategories.where((s) => s.title.toLowerCase() == subCategoryTitle.toLowerCase()).firstOrNull;
      if (sub != null) return sub.icon;
    }
    return Icons.label_outline_rounded;
  }

  static List<String> getSubCategoriesFor(String categoryTitle) {
    final cat = categories.where((c) => c.title.toLowerCase() == categoryTitle.toLowerCase()).firstOrNull;
    if (cat != null) {
      return cat.subCategories.map((s) => s.title).toList();
    }
    return ['Others'];
  }
}
