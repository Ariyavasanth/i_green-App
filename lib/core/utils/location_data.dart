class PincodeResult {
  final String district;
  final String state;
  final bool isValid;
  final String? errorMessage;

  const PincodeResult({
    required this.district,
    required this.state,
    required this.isValid,
    this.errorMessage,
  });
}

class LocationDataHelper {
  static const List<String> countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'United Arab Emirates',
    'Oman',
    'Singapore',
    'Saudi Arabia',
    'Malaysia',
    'Japan',
    'China',
    'Brazil',
    'South Africa',
  ];

  static const Map<String, List<String>> countryStatesMap = {
    'India': [
      'Andaman and Nicobar Islands',
      'Andhra Pradesh',
      'Arunachal Pradesh',
      'Assam',
      'Bihar',
      'Chandigarh',
      'Chhattisgarh',
      'Dadra and Nagar Haveli and Daman and Diu',
      'Delhi',
      'Goa',
      'Gujarat',
      'Haryana',
      'Himachal Pradesh',
      'Jammu and Kashmir',
      'Jharkhand',
      'Karnataka',
      'Kerala',
      'Ladakh',
      'Lakshadweep',
      'Madhya Pradesh',
      'Maharashtra',
      'Manipur',
      'Meghalaya',
      'Mizoram',
      'Nagaland',
      'Odisha',
      'Puducherry',
      'Punjab',
      'Rajasthan',
      'Sikkim',
      'Tamil Nadu',
      'Telangana',
      'Tripura',
      'Uttar Pradesh',
      'Uttarakhand',
      'West Bengal',
    ],
    'United States': [
      'Alabama',
      'Alaska',
      'Arizona',
      'Arkansas',
      'California',
      'Colorado',
      'Connecticut',
      'Delaware',
      'Florida',
      'Georgia',
      'Hawaii',
      'Idaho',
      'Illinois',
      'Indiana',
      'Iowa',
      'Kansas',
      'Kentucky',
      'Louisiana',
      'Maine',
      'Maryland',
      'Massachusetts',
      'Michigan',
      'Minnesota',
      'Mississippi',
      'Missouri',
      'Montana',
      'Nebraska',
      'Nevada',
      'New Hampshire',
      'New Jersey',
      'New Mexico',
      'New York',
      'North Carolina',
      'North Dakota',
      'Ohio',
      'Oklahoma',
      'Oregon',
      'Pennsylvania',
      'Rhode Island',
      'South Carolina',
      'South Dakota',
      'Tennessee',
      'Texas',
      'Utah',
      'Vermont',
      'Virginia',
      'Washington',
      'West Virginia',
      'Wisconsin',
      'Wyoming',
    ],
    'United Kingdom': [
      'England',
      'Scotland',
      'Wales',
      'Northern Ireland',
    ],
    'Canada': [
      'Alberta',
      'British Columbia',
      'Manitoba',
      'New Brunswick',
      'Newfoundland and Labrador',
      'Nova Scotia',
      'Ontario',
      'Prince Edward Island',
      'Quebec',
      'Saskatchewan',
    ],
    'Australia': [
      'New South Wales',
      'Queensland',
      'South Australia',
      'Tasmania',
      'Victoria',
      'Western Australia',
      'Australian Capital Territory',
      'Northern Territory',
    ],
    'United Arab Emirates': [
      'Abu Dhabi',
      'Ajman',
      'Dubai',
      'Fujairah',
      'Ras Al Khaimah',
      'Sharjah',
      'Umm Al Quwain',
    ],
    'Oman': [
  'Muscat',
  'Salalah',
  'Sohar',
  'Nizwa',
  'Sur',
  'Ibri',
  'Rustaq',
  'Barka',
  'Khasab',
  'Al Buraimi',
  'Ibra',
  'Duqm',
  'Al Hamra',
  'Bahla',
],
  };

  static List<String> getStatesForCountry(String country) {
    if (countryStatesMap.containsKey(country)) {
      return countryStatesMap[country]!;
    }
    return ['Default Region / State'];
  }

  static PincodeResult lookupPincode(String pincode, String country) {
    final cleanPin = pincode.trim();
    if (cleanPin.isEmpty) {
      return const PincodeResult(
        district: '',
        state: '',
        isValid: true,
      );
    }

    if (country == 'India') {
      if (!RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
        return const PincodeResult(
          district: '',
          state: '',
          isValid: false,
          errorMessage: 'Pincode must be a 6-digit number.',
        );
      }

      if (cleanPin.startsWith('000000') || cleanPin.startsWith('999999')) {
        return const PincodeResult(
          district: '',
          state: '',
          isValid: false,
          errorMessage: 'Invalid pincode format.',
        );
      }

      final prefix3 = cleanPin.substring(0, 3);
      final prefix2 = cleanPin.substring(0, 2);

      // Exact 6-digit overrides / specific mappings
      if (cleanPin == '600058') {
        return const PincodeResult(district: 'Chennai', state: 'Tamil Nadu', isValid: true);
      }
      if (cleanPin == '600116') {
        return const PincodeResult(district: 'Tiruvallur', state: 'Tamil Nadu', isValid: true);
      }

      // 3-digit prefix mapping for India
      switch (prefix3) {
        // Tamil Nadu & Puducherry
        case '600':
          return const PincodeResult(district: 'Chennai', state: 'Tamil Nadu', isValid: true);
        case '601':
        case '603':
          return const PincodeResult(district: 'Chengalpattu', state: 'Tamil Nadu', isValid: true);
        case '602':
          return const PincodeResult(district: 'Tiruvallur', state: 'Tamil Nadu', isValid: true);
        case '604':
          return const PincodeResult(district: 'Villupuram', state: 'Tamil Nadu', isValid: true);
        case '605':
          return const PincodeResult(district: 'Puducherry', state: 'Puducherry', isValid: true);
        case '606':
        case '607':
        case '608':
          return const PincodeResult(district: 'Cuddalore', state: 'Tamil Nadu', isValid: true);
        case '609':
          return const PincodeResult(district: 'Mayiladuthurai', state: 'Tamil Nadu', isValid: true);
        case '610':
          return const PincodeResult(district: 'Thiruvarur', state: 'Tamil Nadu', isValid: true);
        case '611':
          return const PincodeResult(district: 'Nagapattinam', state: 'Tamil Nadu', isValid: true);
        case '612':
        case '613':
        case '614':
          return const PincodeResult(district: 'Thanjavur', state: 'Tamil Nadu', isValid: true);
        case '620':
          return const PincodeResult(district: 'Tiruchirappalli', state: 'Tamil Nadu', isValid: true);
        case '621':
          return const PincodeResult(district: 'Perambalur', state: 'Tamil Nadu', isValid: true);
        case '622':
          return const PincodeResult(district: 'Pudukkottai', state: 'Tamil Nadu', isValid: true);
        case '623':
          return const PincodeResult(district: 'Ramanathapuram', state: 'Tamil Nadu', isValid: true);
        case '624':
          return const PincodeResult(district: 'Dindigul', state: 'Tamil Nadu', isValid: true);
        case '625':
          return const PincodeResult(district: 'Madurai', state: 'Tamil Nadu', isValid: true);
        case '626':
          return const PincodeResult(district: 'Virudhunagar', state: 'Tamil Nadu', isValid: true);
        case '627':
          return const PincodeResult(district: 'Tirunelveli', state: 'Tamil Nadu', isValid: true);
        case '628':
          return const PincodeResult(district: 'Thoothukudi', state: 'Tamil Nadu', isValid: true);
        case '629':
          return const PincodeResult(district: 'Kanyakumari', state: 'Tamil Nadu', isValid: true);
        case '630':
          return const PincodeResult(district: 'Sivaganga', state: 'Tamil Nadu', isValid: true);
        case '631':
          return const PincodeResult(district: 'Ranipet', state: 'Tamil Nadu', isValid: true);
        case '632':
          return const PincodeResult(district: 'Vellore', state: 'Tamil Nadu', isValid: true);
        case '635':
          return const PincodeResult(district: 'Krishnagiri', state: 'Tamil Nadu', isValid: true);
        case '636':
          return const PincodeResult(district: 'Salem', state: 'Tamil Nadu', isValid: true);
        case '637':
          return const PincodeResult(district: 'Namakkal', state: 'Tamil Nadu', isValid: true);
        case '638':
          return const PincodeResult(district: 'Erode', state: 'Tamil Nadu', isValid: true);
        case '639':
          return const PincodeResult(district: 'Karur', state: 'Tamil Nadu', isValid: true);
        case '641':
          return const PincodeResult(district: 'Coimbatore', state: 'Tamil Nadu', isValid: true);
        case '642':
          return const PincodeResult(district: 'Tiruppur', state: 'Tamil Nadu', isValid: true);
        case '643':
          return const PincodeResult(district: 'Nilgiris', state: 'Tamil Nadu', isValid: true);

        // Karnataka
        case '560':
          return const PincodeResult(district: 'Bengaluru Urban', state: 'Karnataka', isValid: true);
        case '561':
        case '562':
          return const PincodeResult(district: 'Bengaluru Rural', state: 'Karnataka', isValid: true);
        case '570':
          return const PincodeResult(district: 'Mysuru', state: 'Karnataka', isValid: true);
        case '571':
          return const PincodeResult(district: 'Mandya', state: 'Karnataka', isValid: true);
        case '572':
          return const PincodeResult(district: 'Tumakuru', state: 'Karnataka', isValid: true);
        case '573':
          return const PincodeResult(district: 'Hassan', state: 'Karnataka', isValid: true);
        case '574':
        case '575':
          return const PincodeResult(district: 'Dakshina Kannada', state: 'Karnataka', isValid: true);
        case '576':
          return const PincodeResult(district: 'Udupi', state: 'Karnataka', isValid: true);
        case '577':
          return const PincodeResult(district: 'Shivamogga', state: 'Karnataka', isValid: true);
        case '580':
          return const PincodeResult(district: 'Dharwad', state: 'Karnataka', isValid: true);
        case '590':
          return const PincodeResult(district: 'Belagavi', state: 'Karnataka', isValid: true);

        // Maharashtra
        case '400':
          return const PincodeResult(district: 'Mumbai City', state: 'Maharashtra', isValid: true);
        case '401':
          return const PincodeResult(district: 'Palghar', state: 'Maharashtra', isValid: true);
        case '410':
        case '411':
        case '412':
          return const PincodeResult(district: 'Pune', state: 'Maharashtra', isValid: true);
        case '421':
          return const PincodeResult(district: 'Thane', state: 'Maharashtra', isValid: true);
        case '422':
          return const PincodeResult(district: 'Nashik', state: 'Maharashtra', isValid: true);
        case '431':
          return const PincodeResult(district: 'Chhatrapati Sambhajinagar', state: 'Maharashtra', isValid: true);
        case '440':
          return const PincodeResult(district: 'Nagpur', state: 'Maharashtra', isValid: true);

        // Delhi & NCR
        case '110':
          return const PincodeResult(district: 'New Delhi', state: 'Delhi', isValid: true);
        case '122':
          return const PincodeResult(district: 'Gurugram', state: 'Haryana', isValid: true);
        case '121':
          return const PincodeResult(district: 'Faridabad', state: 'Haryana', isValid: true);
        case '201':
          return const PincodeResult(district: 'Gautam Buddha Nagar', state: 'Uttar Pradesh', isValid: true);
        case '226':
          return const PincodeResult(district: 'Lucknow', state: 'Uttar Pradesh', isValid: true);
        case '208':
          return const PincodeResult(district: 'Kanpur Nagar', state: 'Uttar Pradesh', isValid: true);
        case '282':
          return const PincodeResult(district: 'Agra', state: 'Uttar Pradesh', isValid: true);
        case '221':
          return const PincodeResult(district: 'Varanasi', state: 'Uttar Pradesh', isValid: true);

        // Telangana & AP
        case '500':
          return const PincodeResult(district: 'Hyderabad', state: 'Telangana', isValid: true);
        case '501':
          return const PincodeResult(district: 'Ranga Reddy', state: 'Telangana', isValid: true);
        case '506':
          return const PincodeResult(district: 'Hanamkonda', state: 'Telangana', isValid: true);
        case '530':
          return const PincodeResult(district: 'Visakhapatnam', state: 'Andhra Pradesh', isValid: true);
        case '520':
          return const PincodeResult(district: 'NTR Vijayawada', state: 'Andhra Pradesh', isValid: true);
        case '522':
          return const PincodeResult(district: 'Guntur', state: 'Andhra Pradesh', isValid: true);
        case '517':
          return const PincodeResult(district: 'Tirupati', state: 'Andhra Pradesh', isValid: true);

        // Rajasthan & Gujarat
        case '302':
          return const PincodeResult(district: 'Jaipur', state: 'Rajasthan', isValid: true);
        case '342':
          return const PincodeResult(district: 'Jodhpur', state: 'Rajasthan', isValid: true);
        case '380':
          return const PincodeResult(district: 'Ahmedabad', state: 'Gujarat', isValid: true);
        case '395':
          return const PincodeResult(district: 'Surat', state: 'Gujarat', isValid: true);
        case '390':
          return const PincodeResult(district: 'Vadodara', state: 'Gujarat', isValid: true);

        // Kerala & Bengal & others
        case '682':
          return const PincodeResult(district: 'Ernakulam', state: 'Kerala', isValid: true);
        case '695':
          return const PincodeResult(district: 'Thiruvananthapuram', state: 'Kerala', isValid: true);
        case '673':
          return const PincodeResult(district: 'Kozhikode', state: 'Kerala', isValid: true);
        case '700':
          return const PincodeResult(district: 'Kolkata', state: 'West Bengal', isValid: true);
        case '711':
          return const PincodeResult(district: 'Howrah', state: 'West Bengal', isValid: true);
        case '800':
          return const PincodeResult(district: 'Patna', state: 'Bihar', isValid: true);
        case '834':
          return const PincodeResult(district: 'Ranchi', state: 'Jharkhand', isValid: true);
        case '751':
          return const PincodeResult(district: 'Khurda', state: 'Odisha', isValid: true);
        case '781':
          return const PincodeResult(district: 'Kamrup Metropolitan', state: 'Assam', isValid: true);
        case '160':
          return const PincodeResult(district: 'Chandigarh', state: 'Chandigarh', isValid: true);
        case '171':
          return const PincodeResult(district: 'Shimla', state: 'Himachal Pradesh', isValid: true);
        case '190':
          return const PincodeResult(district: 'Srinagar', state: 'Jammu and Kashmir', isValid: true);
      }

      // 2-digit state-level fallbacks for any other valid 6-digit Indian pincode
      switch (prefix2) {
        case '60':
        case '61':
        case '62':
        case '63':
        case '64':
          return const PincodeResult(district: 'Tamil Nadu District', state: 'Tamil Nadu', isValid: true);
        case '56':
        case '57':
        case '58':
        case '59':
          return const PincodeResult(district: 'Karnataka District', state: 'Karnataka', isValid: true);
        case '40':
        case '41':
        case '42':
        case '43':
        case '44':
          return const PincodeResult(district: 'Maharashtra District', state: 'Maharashtra', isValid: true);
        case '11':
          return const PincodeResult(district: 'Delhi District', state: 'Delhi', isValid: true);
        case '12':
        case '13':
          return const PincodeResult(district: 'Haryana District', state: 'Haryana', isValid: true);
        case '14':
        case '15':
          return const PincodeResult(district: 'Punjab District', state: 'Punjab', isValid: true);
        case '20':
        case '21':
        case '22':
        case '23':
        case '24':
        case '25':
        case '26':
        case '27':
        case '28':
          return const PincodeResult(district: 'Uttar Pradesh District', state: 'Uttar Pradesh', isValid: true);
        case '30':
        case '31':
        case '32':
        case '33':
        case '34':
          return const PincodeResult(district: 'Rajasthan District', state: 'Rajasthan', isValid: true);
        case '36':
        case '37':
        case '38':
        case '39':
          return const PincodeResult(district: 'Gujarat District', state: 'Gujarat', isValid: true);
        case '45':
        case '46':
        case '47':
        case '48':
          return const PincodeResult(district: 'Madhya Pradesh District', state: 'Madhya Pradesh', isValid: true);
        case '50':
          return const PincodeResult(district: 'Telangana District', state: 'Telangana', isValid: true);
        case '51':
        case '52':
        case '53':
          return const PincodeResult(district: 'Andhra Pradesh District', state: 'Andhra Pradesh', isValid: true);
        case '67':
        case '68':
        case '69':
          return const PincodeResult(district: 'Kerala District', state: 'Kerala', isValid: true);
        case '70':
        case '71':
        case '72':
        case '73':
        case '74':
          return const PincodeResult(district: 'West Bengal District', state: 'West Bengal', isValid: true);
        case '75':
        case '76':
        case '77':
          return const PincodeResult(district: 'Odisha District', state: 'Odisha', isValid: true);
        case '78':
          return const PincodeResult(district: 'Assam District', state: 'Assam', isValid: true);
        case '80':
        case '81':
        case '82':
        case '83':
        case '84':
        case '85':
          return const PincodeResult(district: 'Bihar District', state: 'Bihar', isValid: true);
        default:
          return const PincodeResult(
            district: 'Central District',
            state: 'India',
            isValid: true,
          );
      }
    } else {
      if (cleanPin.length < 3 || cleanPin.length > 10) {
        return PincodeResult(
          district: '',
          state: '',
          isValid: false,
          errorMessage: 'Invalid postal code for $country.',
        );
      }
      return PincodeResult(
        district: '$country District',
        state: getStatesForCountry(country).first,
        isValid: true,
      );
    }
  }
}
