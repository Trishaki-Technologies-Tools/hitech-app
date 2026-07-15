import 'dart:math'; // For random quotation number generation
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/lead_model.dart';
import '../../services/api_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../services/msg91_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class BrochureItem {
  final String title;
  final String subtitle;
  final String description;
  final String size;
  final String pdfUrl;
  final IconData icon;
  final String category;

  const BrochureItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.size,
    required this.pdfUrl,
    required this.icon,
    required this.category,
  });
}

class LeadFormScreen extends StatefulWidget {
  final LeadModel? prefilledEnquiry;
  const LeadFormScreen({super.key, this.prefilledEnquiry});

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  // Add Lead Form Controllers & States
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _reqController = TextEditingController();

  // New Particulars Controllers
  final _exShowroomController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _netInvoiceController = TextEditingController(text: '0');
  final _speedGovernorController = TextEditingController(text: '0');
  final _insuranceController = TextEditingController(text: '0');
  final _roadTaxController = TextEditingController(text: '0');
  final _handlingChargeController = TextEditingController(text: '0');
  final _accessoriesController = TextEditingController(text: '0');
  final _fasTagController = TextEditingController(text: '0');
  final _tcsController = TextEditingController(text: '0');
  final _totalOnRoadController = TextEditingController(text: '0');
  final _amountInWordsController = TextEditingController(text: 'Zero Rupees Only');

  bool _isLoading = false;

  String _quotationNo = '';
  String _dateStr = '';
  String? _selectedVehicle;

  final ApiService _apiService = ApiService();

  // Brochure Form Controllers & States
  final _brochureNameController = TextEditingController();
  final _brochurePhoneController = TextEditingController();
  bool _isBrochureLoading = false;

  String _brochureDateStr = '';
  String? _brochureSelectedVehicle;
  String _selectedTempStatus = 'Cold';

  // Brochures list fetched from database settings
  List<Map<String, dynamic>> _dbBrochures = [];
  bool _isLoadingBrochures = false;

  // Enquiry Form Controllers & States
  final _enquiryNameController = TextEditingController();
  final _enquiryPhoneController = TextEditingController();
  final _enquiryAlternatePhoneController = TextEditingController();
  final _enquiryPlaceController = TextEditingController();
  final _enquiryFollowUpDateController = TextEditingController();
  bool _isEnquiryLoading = false;
  String _enquiryDateStr = '';
  String? _enquirySelectedVehicle;

  // New Enquiry Form Controllers
  final _enquiryEmailController = TextEditingController();
  final _enquiryPincodeController = TextEditingController();
  final _enquiryProviderPhoneController = TextEditingController();
  
  // Selected dropdown options
  String? _enquirySelectedState;
  String? _enquirySelectedCity;
  String? _enquirySelectedSegment;
  String? _enquirySelectedBrand;
  String? _enquirySelectedVehicleUsage;
  String? _enquirySelectedFleetMix;
  String? _enquirySelectedPrimaryApp;
  String? _enquirySelectedSecondaryApp;
  String? _enquirySelectedSource;

  // Location Coordinate Fetching states
  double? _userLatitude;
  double? _userLongitude;
  bool _isFetchingLocation = false;

  // Complete India States and Cities Database
  final Map<String, List<String>> _indiaStatesAndCities = const {
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Rajahmundry', 'Tirupati', 'Kakinada', 'Anantapur', 'Eluru', 'Other'],
    'Arunachal Pradesh': ['Itanagar', 'Naharlagun', 'Pasighat', 'Namsai', 'Other'],
    'Assam': ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia', 'Other'],
    'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga', 'Arrah', 'Begusarai', 'Other'],
    'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Rajnandgaon', 'Other'],
    'Delhi': ['New Delhi', 'Dwarka', 'Rohini', 'Vasant Kunj', 'Shahdara', 'Noida-NCR', 'Other'],
    'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda', 'Other'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Gandhinagar', 'Junagadh', 'Other'],
    'Haryana': ['Faridabad', 'Gurugram', 'Panipat', 'Ambala', 'Yamunanagar', 'Rohtak', 'Hisar', 'Karnal', 'Other'],
    'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Solan', 'Mandi', 'Una', 'Other'],
    'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag', 'Baramulla', 'Kathua', 'Other'],
    'Jharkhand': ['Jamshedpur', 'Dhanbad', 'Ranchi', 'Bokaro Steel City', 'Deoghar', 'Other'],
    'Karnataka': ['Bengaluru', 'Hubballi-Dharwad', 'Mysuru', 'Kalaburagi', 'Belagavi', 'Mangaluru', 'Davanagere', 'Ballari', 'Other'],
    'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Kollam', 'Thrissur', 'Alappuzha', 'Palakkad', 'Other'],
    'Madhya Pradesh': ['Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas', 'Satna', 'Ratlam', 'Rewa', 'Other'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Pimpri-Chinchwad', 'Nashik', 'Kalyan-Dombivli', 'Vasai-Virar', 'Aurangabad', 'Navi Mumbai', 'Other'],
    'Manipur': ['Imphal', 'Thoubal', 'Kakching', 'Other'],
    'Meghalaya': ['Shillong', 'Tura', 'Nongpoh', 'Other'],
    'Mizoram': ['Aizawl', 'Lunglei', 'Champhai', 'Other'],
    'Nagaland': ['Dimapur', 'Kohima', 'Mokokchung', 'Other'],
    'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Sambalpur', 'Puri', 'Balasore', 'Other'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali', 'Hoshiarpur', 'Pathankot', 'Other'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Kota', 'Bikaner', 'Ajmer', 'Udaipur', 'Bhilwara', 'Alwar', 'Sikar', 'Other'],
    'Sikkim': ['Gangtok', 'Namchi', 'Geyzing', 'Other'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tiruppur', 'Erode', 'Vellore', 'Thoothukudi', 'Other'],
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar', 'Ramagundam', 'Other'],
    'Tripura': ['Agartala', 'Dharmanagar', 'Udaipur', 'Other'],
    'Uttar Pradesh': ['Meerut', 'Lucknow', 'Kanpur', 'Noida', 'Ghaziabad', 'Varanasi', 'Agra', 'Prayagraj', 'Bareilly', 'Aligarh', 'Moradabad', 'Gorakhpur', 'Other'],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Haldwani', 'Roorkee', 'Kashipur', 'Other'],
    'West Bengal': ['Kolkata', 'Howrah', 'Siliguri', 'Asansol', 'Durgapur', 'Bardhaman', 'Malda', 'Other'],
    'Other Territory': ['Other City'],
  };

  void _showSearchablePicker({
    required String title,
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredItems = items
                .where((item) => item.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3F51B5),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Search Bar
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search State/City...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF3F51B5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Items List
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching items found',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final isSelected = item == selectedValue;
                                return ListTile(
                                  title: Text(
                                    item,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? const Color(0xFF3F51B5) : Colors.black87,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Color(0xFF3F51B5))
                                      : null,
                                  onTap: () {
                                    onSelected(item);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dropdown static data lists
  final List<String> _segments = const [
    'LCV CARGO',
    'LCV PASSENGER',
    'SCV CARGO',
  ];

  final Map<String, List<String>> _segmentBrands = const {
    'LCV CARGO': ['Partner'],
    'LCV PASSENGER': ['MITR SCHOOL', 'MITR STANDARD'],
    'SCV CARGO': [
      'BADA DOST CNG',
      'BADA DOST I1',
      'BADA DOST I2',
      'BADA DOST I3',
      'BADA DOST i3+LNT',
      'BADA dost i3+XL',
      'bada dost i4',
      'bada dost i4 LNT',
      'bada dost i5',
      'bada dost i5+',
      'bada dost i5+xl',
      'bada dost i5xl',
      'bada dost 6',
      'dost +',
      'dost cash van',
      'dost cng',
      'dost garbage tipper',
      'dost ref container',
      'dost smart',
      'dost strong',
      'dost twin fuel',
      'dost xl',
      'dost+ CNG',
      'dost+ XL',
      'dost+XL CNG',
      'dost+XL TWIN FUEL',
      'SAATHI',
    ],
  };

  final Map<String, List<String>> _segmentPrimaryApps = const {
    'LCV CARGO': [
      'BEVERAGES',
      'CONSTRUCTION MATERIAL',
      'HOMENEEDS / RETAIL CHAIN LOGISTIS',
      'PERISHABLE / AGRI',
      'READY TO USE VEHICLES ( RUV )',
      'SPECIFIC GOODS TRANSPORT',
    ],
    'SCV CARGO': [
      'BEVERAGES',
      'CONSTRUCTION MATERIAL',
      'HOMENEEDS / RETAIL CHAIN LOGISTIS',
      'PERISHABLE / AGRI',
      'READY TO USE VEHICLES ( RUV )',
      'SPECIFIC GOODS TRANSPORT',
    ],
    'LCV PASSENGER': [
      'COMMERCIAL CATEGORY',
    ],
  };

  final Map<String, List<String>> _primaryToSecondaryApps = const {
    'BEVERAGES': [
      'AERATED DRINKS',
      'LIQUOR',
      'PACKAGED WATER',
    ],
    'CONSTRUCTION MATERIAL': [
      'CEMENT BAGS',
      'ELECTRICAL / SANITARY FITTINGS',
      'FLOOR TILES / MARBLE SLABS',
      'GLAASS SHEETS',
      'HARDWARE ITEMS - LATCHES/DOOR HINGES/LOCKS',
      'MS BARS / PLASTIC/STEEL PPIPPES',
      'PAINT',
      'SAND / BRICK / BLUE METAL / SOIL /STONES',
      'SAND/BRICK/BLUE METAL',
    ],
    'HOMENEEDS / RETAIL CHAIN LOGISTIS': [
      'FINISHED GARMENTS',
      'FMCG(PROVISIONS LIKE TOILETRIES/COSMETICS/NAMKEENS)',
      'FURNITURE',
      'LPG SUPPLIES',
      'RETAIL STORES',
      'STATIONERIES / PAPER ROLLS / NEWSPAPER',
      'TENT-SHAMIYANA AND PANDAAL',
      'WHITE GOODS - TV / WASHING MACHINE / AC / REFRIGERATOR ETC',
    ],
    'PERISHABLE / AGRI': [
      'CATERING - FOOD BY HOTELS / RESTAURANTS',
      'CONFECTIONERIES - BREAD / CAKE',
      'EGG / POULTRY',
      'FISH / MEAT',
      'FLOWERS',
      'FOOD GRAINS / PULSES / SALT',
      'FRUITS',
      'ICE CREAMS',
      'MILK / MILK PROD',
      'VEGETABLES',
    ],
    'READY TO USE VEHICLES ( RUV )': [
      'AMBULANCE',
      'CASH VAN',
      'CNG SUPPLIES',
      'CONSTRUCTION TIPPER',
      'FUEL TANKER',
      'GARBAGE/WASTE DISPOSAL',
      'HEARSE VAN',
      'MOBILE HOARDINGS',
      'MOBILE RESTAURANT / KITCHEN ON WHEELS',
      'SERVICE-AT-SITE(SAS) VAN',
      'SKY LIFT / TAIL LIFT',
      'WATER TANKER',
    ],
    'SPECIFIC GOODS TRANSPORT': [
      'AIR CARGO SHIPMENTS',
      'CATTLE TRANSPORTATION',
      'INDUSTRIAL SUPPLIERS-(COMPONENTS/MACHINE TOOLS)',
      'LUBRICANTS / PETROLEUM PRODUCTS / CHEMICALS',
      'METAL SCRAP',
      'OXYGEN CYLINDERS',
      'PACKKERS AND MOVERS',
      'PARCEL AND COURIER SERVICE',
      'PHARMACEUTICALS',
      'PLYWOOD',
      'RAW MATERIAL - TEXTILESS',
      'TYRES - RETREAD',
    ],
    'COMMERCIAL CATEGORY': [
      'SCHOOL BUS',
      'STAFF TRANSPORTATION',
      'STAGE CARRIAGE PERMIT',
      'TOURIST PERMIT',
    ],
  };

  final Map<String, List<String>> _segmentVehicleUsages = const {
    'LCV CARGO': [
      'CAPTIVE',
      'CONTRACT',
      'MARKET LOAD OPERATOR',
    ],
    'SCV CARGO': [
      'CAPTIVE',
      'CONTRACT',
      'MARKET LOAD OPERATOR',
    ],
    'LCV PASSENGER': [
      'CAPTIVE',
      'CONTRACT PRIVATE SERVICE VEH',
      'MAXICAB-TOURIST',
      'OMNIBUS-PERMIT',
      'SCHOOL BUS',
    ],
  };

  final List<String> _fleetMixes = const [
    'Additional Vehicle Buyer',
    'AL Customer',
    'AL DOST Customer',
    'Competitor Customer',
    'DOST Competitor Customer',
    'Exchange Buyer',
    'First Time Buyer',
    'FTB AL Customer',
    'FTB JD Customer',
    'Light Comm Mixed Fleet',
    'Mixed Fleet',
    'Mixed Fleet Operator',
    'Others',
    'Repeat Purchase',
    'Small Comm Mixed Fleet',
  ];

  final List<String> _sourcesOfEnquiry = const [
    '91 Trucks',
    'AL Call Centre',
    'ALTT',
    'Cold Calls',
    'DOST 1 Lac Celebration',
    'Dost 5th Anniversary Mahotsav',
    'Event/Campaign',
    'Exchange',
    'Field',
    'Hyperlocal',
    'Loyalty',
    'MDV',
    'Online Booking',
    'Others',
    'Referral',
    'Referral Customer /Workshop Staff',
    'Referral Customer/HO',
    'Referral Service/Workshop Staff',
    'Rural growth Marketers-AL',
    'Rural growth Marketers-CSC eStore',
    'Rural growth Marketers-Gro Service Mandi',
    'Telemarketing',
    'Telephone In',
    'Walk in',
    'Web Enquiry',
  ];

  Future<void> _fetchUserCoordinates() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isFetchingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isFetchingLocation = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isFetchingLocation = false);
        return;
      }

      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        setState(() {
          _userLatitude = lastKnown.latitude;
          _userLongitude = lastKnown.longitude;
        });
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
        _isFetchingLocation = false;
      });
    } catch (e) {
      debugPrint("Error fetching coordinates: $e");
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  // Vehicle Variants List
  final List<String> _vehicles = const [
    'SCV Goods Carrier',
    'DOST + XL CNG',
    'SAATHI',
    'BADA DOST i3+ with LNT',
    'BADA DOST i4 with LNT',
    'DOST XL',
    'Bada Dost i3+XL',
    'BADA DOST i3+',
    'DOST + XL',
    'Dost Twin Fuel',
    'Dost + XL Twin Fuel',
    'LCV Goods Carrier',
    'Partner 4 Tyre',
    'Partner 6 Tyre',
    'Other Light Vehicle Variants Seen',
    'Bada Dost i5 XL LS',
    'Bada Dost i5 XL LX',
    'Bada Dost i5+ LX',
    'BADA DOST i5 LX',
    'BADA DOST i5 LS',
    'Bada Dost i5 XL',
    'Bada Dost i5+',
    'BADA DOST i5',
    'BADA DOST i4',
  ];

  List<String> get _sortedVehicles {
    final list = List<String>.from(_vehicles);
    if (_selectedVehicle != null && !list.contains(_selectedVehicle)) {
      list.add(_selectedVehicle!);
    }
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  // Static Brochure List
  final List<BrochureItem> _brochures = const [
    BrochureItem(
      title: 'TrackForce GPS Fleet Tracker',
      subtitle: 'Commercial Fleet Optimization & Telemetry',
      description: 'Complete high-accuracy GPS tracking hardware and software system designed to monitor logistics, track fuel efficiency, secure fleets, and optimize dispatch routes in real-time.',
      size: 'PDF • 3.2 MB',
      pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      icon: Icons.local_shipping_outlined,
      category: 'Hardware',
    ),
    BrochureItem(
      title: 'TrackForce Asset & Cargo GPS',
      subtitle: 'Rugged Magnetic Long-Battery Tracking',
      description: 'Heavy-duty rugged GPS trackers featuring a strong magnetic mount and up to 5 years of autonomous battery life, ideal for cargo containers, flatbeds, heavy equipment, and generators.',
      size: 'PDF • 2.8 MB',
      pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      icon: Icons.inventory_2_outlined,
      category: 'Hardware',
    ),
    BrochureItem(
      title: 'TrackForce Personal Wearable SOS',
      subtitle: 'Lightweight Enterprise Safety Tracker',
      description: 'Compact wearable tracking badges equipped with instant SOS panic buttons, fallback cellular triangulation, fall-down detection, and two-way voice communication for high-risk field workers.',
      size: 'PDF • 1.9 MB',
      pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      icon: Icons.badge_outlined,
      category: 'Hardware',
    ),
    BrochureItem(
      title: 'HiTECH Field Force Portal',
      subtitle: 'Central Operations Control & Dispatch Center',
      description: 'Enterprise-grade cloud platform offering live manager dashboards, geofenced team monitoring, instant dispatcher communication, automated task routing, and comprehensive reports.',
      size: 'PDF • 4.5 MB',
      pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      icon: Icons.business_outlined,
      category: 'Software',
    ),
    BrochureItem(
      title: 'HiTECH DSE Mobile Assistant',
      subtitle: 'Sales Executive App Capability Manual',
      description: 'The definitive field catalog and user guide detailing automation workflows, live check-ins, offline attendance logging, route history tracking, and digital lead capture tools.',
      size: 'PDF • 1.5 MB',
      pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      icon: Icons.app_settings_alt_outlined,
      category: 'Software',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _generateQuotationNo();
    _setCurrentDate();
    _setBrochureCurrentDate();
    _setEnquiryCurrentDate();
    _fetchBrochures();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _fetchUserCoordinates();
        }
      });
    });
    
    // Add listeners to auto-calculate fields
    _exShowroomController.addListener(_calculateTotals);
    _discountController.addListener(_calculateTotals);
    _speedGovernorController.addListener(_calculateTotals);
    _insuranceController.addListener(_calculateTotals);
    _roadTaxController.addListener(_calculateTotals);
    _handlingChargeController.addListener(_calculateTotals);
    _accessoriesController.addListener(_calculateTotals);
    _fasTagController.addListener(_calculateTotals);
    _tcsController.addListener(_calculateTotals);

    // Prefill data if a converted enquiry was passed
    if (widget.prefilledEnquiry != null) {
      final lead = widget.prefilledEnquiry!;
      _nameController.text = lead.customerName;
      _phoneController.text = lead.phone;
      _alternatePhoneController.text = lead.alternatePhone ?? '';
      
      // Parse enquiry requirement details
      final lines = lead.requirement.split('\n');
      String place = '';
      String vehicle = '';
      String notes = '';
      for (var line in lines) {
        if (line.contains(':')) {
          final index = line.indexOf(':');
          final key = line.substring(0, index).trim().toLowerCase();
          final val = line.substring(index + 1).trim();
          if (key.contains('place')) {
            place = val;
          } else if (key.contains('vehicle')) {
            vehicle = val;
          } else if (key.contains('note') && !val.toLowerCase().contains('created via')) {
            notes = val;
          }
        }
      }
      
      _addressController.text = place;
      _reqController.text = notes;
      
      // Set matching vehicle variant
      if (vehicle.isNotEmpty) {
        final matched = _vehicles.firstWhere(
          (v) => v.toLowerCase() == vehicle.toLowerCase(),
          orElse: () => '',
        );
        if (matched.isNotEmpty) {
          _selectedVehicle = matched;
        } else {
          final matchedContains = _vehicles.firstWhere(
            (v) => v.toLowerCase().contains(vehicle.toLowerCase()) || vehicle.toLowerCase().contains(v.toLowerCase()),
            orElse: () => '',
          );
          if (matchedContains.isNotEmpty) {
            _selectedVehicle = matchedContains;
          } else {
            _selectedVehicle = vehicle;
          }
        }
      }
    }
  }

  void _generateQuotationNo() {
    final now = DateTime.now();
    final datePart = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final randomPart = Random().nextInt(9000) + 1000;
    setState(() {
      _quotationNo = "QT-$datePart-$randomPart";
    });
  }

  void _setCurrentDate() {
    final now = DateTime.now();
    setState(() {
      _dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    });
  }

  void _setBrochureCurrentDate() {
    final now = DateTime.now();
    setState(() {
      _brochureDateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    });
  }

  void _setEnquiryCurrentDate() {
    final now = DateTime.now();
    setState(() {
      _enquiryDateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _addressController.dispose();
    _reqController.dispose();
    _brochureNameController.dispose();
    _brochurePhoneController.dispose();
    _enquiryNameController.dispose();
    _enquiryPhoneController.dispose();
    _enquiryAlternatePhoneController.dispose();
    _enquiryPlaceController.dispose();
    _enquiryFollowUpDateController.dispose();
    _enquiryEmailController.dispose();
    _enquiryPincodeController.dispose();
    _enquiryProviderPhoneController.dispose();
    
    // Dispose new controllers
    _exShowroomController.dispose();
    _discountController.dispose();
    _netInvoiceController.dispose();
    _speedGovernorController.dispose();
    _insuranceController.dispose();
    _roadTaxController.dispose();
    _handlingChargeController.dispose();
    _accessoriesController.dispose();
    _fasTagController.dispose();
    _tcsController.dispose();
    _totalOnRoadController.dispose();
    _amountInWordsController.dispose();
    
    super.dispose();
  }

  void _calculateTotals() {
    final exShowroom = double.tryParse(_exShowroomController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    
    final netInvoice = exShowroom - discount;
    
    final speedGovernor = double.tryParse(_speedGovernorController.text) ?? 0.0;
    final insurance = double.tryParse(_insuranceController.text) ?? 0.0;
    final roadTax = double.tryParse(_roadTaxController.text) ?? 0.0;
    final handlingCharge = double.tryParse(_handlingChargeController.text) ?? 0.0;
    final accessories = double.tryParse(_accessoriesController.text) ?? 0.0;
    final fasTag = double.tryParse(_fasTagController.text) ?? 0.0;
    final tcs = double.tryParse(_tcsController.text) ?? 0.0;
    
    final totalOnRoad = netInvoice + speedGovernor + insurance + roadTax + handlingCharge + accessories + fasTag + tcs;
    
    _netInvoiceController.text = netInvoice.toStringAsFixed(2);
    _totalOnRoadController.text = totalOnRoad.toStringAsFixed(2);
    
    _amountInWordsController.text = _convertToIndianCurrencyWords(totalOnRoad);
  }

  String _convertToIndianCurrencyWords(double amount) {
    if (amount <= 0) return 'Zero Rupees Only';
    
    int value = amount.round();
    if (value == 0) return 'Zero Rupees Only';
    
    final units = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", 
                   "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"];
    final tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];
    
    String helper(int n) {
      if (n < 20) return units[n];
      if (n < 100) return tens[n ~/ 10] + (n % 10 != 0 ? " ${units[n % 10]}" : "");
      return units[n ~/ 100] + " Hundred" + (n % 100 != 0 ? " and ${helper(n % 100)}" : "");
    }
    
    String words = "";
    int crores = value ~/ 10000000;
    value %= 10000000;
    int lakhs = value ~/ 100000;
    value %= 100000;
    int thousands = value ~/ 1000;
    value %= 1000;
    int remaining = value;
    
    if (crores > 0) {
      words += "${helper(crores)} Crore ";
    }
    if (lakhs > 0) {
      words += "${helper(lakhs)} Lakh ";
    }
    if (thousands > 0) {
      words += "${helper(thousands)} Thousand ";
    }
    if (remaining > 0) {
      words += helper(remaining);
    }
    
    return "${words.trim()} Rupees Only";
  }

  void _submitLead() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final alternatePhone = _alternatePhoneController.text.trim();
    final address = _addressController.text.trim();
    final notes = _reqController.text.trim();
    final vehicle = _selectedVehicle;

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer Name and Mobile Number are required')),
      );
      return;
    }

    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle model')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final exShowroom = _exShowroomController.text;
    final discount = _discountController.text;
    final netInvoice = _netInvoiceController.text;
    final speedGovernor = _speedGovernorController.text;
    final insurance = _insuranceController.text;
    final roadTax = _roadTaxController.text;
    final handling = _handlingChargeController.text;
    final accessories = _accessoriesController.text;
    final fasTag = _fasTagController.text;
    final tcs = _tcsController.text;
    final totalOnRoad = _totalOnRoadController.text;
    final amountWords = _amountInWordsController.text;

    final convertedFromLine = widget.prefilledEnquiry != null
        ? "\nConverted from Enquiry: ${widget.prefilledEnquiry!.id}"
        : "";

    final formattedRequirement = """
Quotation No: $_quotationNo
Date: $_dateStr
Address: ${address.isEmpty ? 'Not Provided' : address}
Model Destribution: $vehicle
${alternatePhone.isNotEmpty ? 'Alternate Phone: $alternatePhone\n' : ''}--------------------------------------
Ex Showroom Price: ₹$exShowroom
Discount: ₹$discount
Net Invoice Price: ₹$netInvoice
Speed Governor: ₹$speedGovernor
Insurance: ₹$insurance
Road Tax / Registration: ₹$roadTax
Handling Charge: ₹$handling
Accessories: ₹$accessories
FAS Tag: ₹$fasTag
TCS: ₹$tcs
--------------------------------------
Total On Road Price: ₹$totalOnRoad
Amount in Words: $amountWords
--------------------------------------
Notes: ${notes.isEmpty ? 'N/A' : notes}$convertedFromLine
""".trim();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    try {
      final Map<String, dynamic> response;
      if (widget.prefilledEnquiry != null) {
        response = await _apiService.patch('update_lead_status.php', {
          'id': widget.prefilledEnquiry!.id,
          'customer_name': name,
          'phone': phone,
          'alternate_phone': alternatePhone.isEmpty ? null : alternatePhone,
          'requirement': formattedRequirement,
          'status': _selectedTempStatus,
        });
      } else {
        response = await _apiService.post('add_lead.php', {
          'customer_name': name,
          'phone': phone,
          'alternate_phone': alternatePhone.isEmpty ? null : alternatePhone,
          'requirement': formattedRequirement,
          'status': _selectedTempStatus,
          if (currentUserId != null) 'assigned_dse': currentUserId,
          if (currentUserId != null) 'dse_id': currentUserId,
          if (currentUserId != null) 'created_by': currentUserId,
        });
      }

      if (response['status'] == 'success') {
        final String actualLeadId = (widget.prefilledEnquiry != null 
            ? widget.prefilledEnquiry!.id 
            : (response['lead_id'] ?? response['id'] ?? "1")).toString();

        String pdfUrl = "https://portal.hitechpragati.in/uploads/quotations/quotation_${_quotationNo.replaceAll('/', '_')}.pdf";

        // 1. Generate & Upload PDF in the background
        try {
          final File pdfFile = await PdfGeneratorService.generateQuotationPdf(
            quotationNo: _quotationNo,
            dateStr: _dateStr,
            customerName: name,
            address: address,
            phone: phone,
            vehicle: vehicle,
            exShowroom: exShowroom,
            discount: discount,
            netInvoice: netInvoice,
            speedGovernor: speedGovernor,
            insurance: insurance,
            roadTax: roadTax,
            handling: handling,
            accessories: accessories,
            fasTag: fasTag,
            tcs: tcs,
            totalOnRoad: totalOnRoad,
            amountWords: amountWords,
            notes: notes,
          );

          final uri = Uri.parse('${ApiService.baseUrl}/quotations.php');
          var request = http.MultipartRequest('POST', uri);
          
          final Map<String, String> headersMap = await ApiService().getHeaders();
          request.headers.addAll(headersMap);

          request.fields['lead_id'] = actualLeadId;
          request.files.add(await http.MultipartFile.fromPath('quotation', pdfFile.path));
          
          var streamedResponse = await request.send();
          var uploadResponse = await http.Response.fromStream(streamedResponse);
          print("----------------------------------------");
          print("SERVER UPLOAD RESPONSE CODE: ${uploadResponse.statusCode}");
          print("SERVER UPLOAD RESPONSE BODY: ${uploadResponse.body}");
          print("----------------------------------------");
          if (uploadResponse.statusCode == 200) {
            try {
              final resData = jsonDecode(uploadResponse.body);
              final String? rawPath = resData['file_path'] ?? resData['url'] ?? resData['file_url'] ?? resData['path'];
              if (rawPath != null) {
                if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
                  pdfUrl = rawPath;
                } else {
                  pdfUrl = "https://portal.hitechpragati.in/$rawPath";
                }
              }
            } catch (_) {}
          }
        } catch (e) {
          print("Error generating/uploading PDF: $e");
        }

        // 2. Call MSG91 Proforma Invoice Bulk Template Service directly
        try {
          final cleanCustomer = name.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '_');
          final cleanVehicle = vehicle.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '_');
          await Msg91Service.sendWhatsAppProformaInvoiceTemplate(
            customerPhone: phone,
            pdfUrl: pdfUrl,
            filename: "${cleanCustomer}_${cleanVehicle}.pdf",
            value1: name,
            value2: _quotationNo,
            value3: vehicle,
            value4: totalOnRoad,
          );
        } catch (e) {
          print("Error sending MSG91 WhatsApp template: $e");
        }

        if (!mounted) return;
        _showSuccessDialog(
          phone: phone,
          name: name,
          quotationNo: _quotationNo,
          dateStr: _dateStr,
          address: address,
          vehicle: vehicle,
          exShowroom: exShowroom,
          discount: discount,
          netInvoice: netInvoice,
          speedGovernor: speedGovernor,
          insurance: insurance,
          roadTax: roadTax,
          handling: handling,
          accessories: accessories,
          fasTag: fasTag,
          tcs: tcs,
          totalOnRoad: totalOnRoad,
          amountWords: amountWords,
          notes: notes,
          leadId: actualLeadId,
        );
        _nameController.clear();
        _phoneController.clear();
        _alternatePhoneController.clear();
        _addressController.clear();
        _reqController.clear();
        
        // Reset pricing fields
        _exShowroomController.text = '0';
        _discountController.text = '0';
        _speedGovernorController.text = '0';
        _insuranceController.text = '0';
        _roadTaxController.text = '0';
        _handlingChargeController.text = '0';
        _accessoriesController.text = '0';
        _fasTagController.text = '0';
        _tcsController.text = '0';
        
        setState(() {
          _selectedVehicle = null;
          _selectedTempStatus = 'Cold';
        });
        _generateQuotationNo(); // Refresh quote code for next lead
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _submitEnquiryLead() async {
    final name = _enquiryNameController.text.trim();
    final phone = _enquiryPhoneController.text.trim();
    final alternatePhone = _enquiryAlternatePhoneController.text.trim();
    final email = _enquiryEmailController.text.trim();
    final state = _enquirySelectedState;
    final city = _enquirySelectedCity;
    final pincode = _enquiryPincodeController.text.trim();
    final segment = _enquirySelectedSegment;
    final brand = _enquirySelectedBrand;
    final vehicleUsage = _enquirySelectedVehicleUsage;
    final fleetMix = _enquirySelectedFleetMix;
    final primaryApp = _enquirySelectedPrimaryApp;
    final secondaryApp = _enquirySelectedSecondaryApp;
    final source = _enquirySelectedSource;
    final providerPhone = _enquiryProviderPhoneController.text.trim();
    final followUpDate = _enquiryFollowUpDateController.text.trim();
    final vehicle = _enquirySelectedVehicle; // Optional Vehicle model variant

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer Name and Mobile Number are required')),
      );
      return;
    }

    if (state == null || city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('State and City are required')),
      );
      return;
    }

    if (segment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Segment selection is required')),
      );
      return;
    }

    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand selection is required')),
      );
      return;
    }

    if (vehicleUsage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle Usage is required')),
      );
      return;
    }

    if (fleetMix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fleet Mix is required')),
      );
      return;
    }

    if (primaryApp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primary Application is required')),
      );
      return;
    }

    if (secondaryApp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secondary Application is required')),
      );
      return;
    }

    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source of Enquiry is required')),
      );
      return;
    }

    if (followUpDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow Up Date is required')),
      );
      return;
    }

    setState(() => _isEnquiryLoading = true);

    // Format coordinates
    final coordinatesStr = (_userLatitude != null && _userLongitude != null)
        ? "$_userLatitude, $_userLongitude"
        : "Not Available";

    final placeStr = "$city, $state";

    // Build the robust and comprehensive multiline requirement details
    final formattedRequirement = """
Customer Name: $name
Customer Phone: $phone
Date: $_enquiryDateStr
${alternatePhone.isNotEmpty ? 'Alternate Phone: $alternatePhone\n' : ''}Customer Email: ${email.isEmpty ? 'N/A' : email}
Place: $placeStr
State: $state
City: $city
Pincode: ${pincode.isEmpty ? 'N/A' : pincode}
Segment: $segment
Brand: $brand
Vehicle: ${vehicle ?? 'N/A'}
Vehicle Usage: $vehicleUsage
Fleet Mix: $fleetMix
Primary Application: $primaryApp
Secondary Application: $secondaryApp
Source of Enquiry: $source
Enquiry Provider Phone: ${providerPhone.isEmpty ? 'N/A' : providerPhone}
Follow Up Date: $followUpDate
Coordinates: $coordinatesStr
Note: Lead created via Enquiry form.
""";

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    try {
      final response = await _apiService.post('add_lead.php', {
        'customer_name': name,
        'phone': phone,
        'alternate_phone': alternatePhone.isEmpty ? null : alternatePhone,
        'requirement': formattedRequirement,
        if (currentUserId != null) 'assigned_dse': currentUserId,
        if (currentUserId != null) 'dse_id': currentUserId,
        if (currentUserId != null) 'created_by': currentUserId,
      });

      if (response['status'] == 'success') {
        if (!mounted) return;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Success'),
              ],
            ),
            content: const Text(
              'Enquiry has been added successfully.',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        // Clear all fields
        _enquiryNameController.clear();
        _enquiryPhoneController.clear();
        _enquiryAlternatePhoneController.clear();
        _enquiryEmailController.clear();
        _enquiryPincodeController.clear();
        _enquiryProviderPhoneController.clear();
        _enquiryFollowUpDateController.clear();
        
        setState(() {
          _enquirySelectedState = null;
          _enquirySelectedCity = null;
          _enquirySelectedSegment = null;
          _enquirySelectedBrand = null;
          _enquirySelectedVehicleUsage = null;
          _enquirySelectedFleetMix = null;
          _enquirySelectedPrimaryApp = null;
          _enquirySelectedSecondaryApp = null;
          _enquirySelectedSource = null;
          _enquirySelectedVehicle = null;
        });

        // Background call to refetchSnappy positioning for next DSE entry
        _fetchUserCoordinates();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isEnquiryLoading = false);
      }
    }
  }

  void _submitBrochureLead() async {
    final name = _brochureNameController.text.trim();
    final phone = _brochurePhoneController.text.trim();
    final vehicle = _brochureSelectedVehicle;

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer Name and Mobile Number are required')),
      );
      return;
    }

    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle model')),
      );
      return;
    }

    setState(() => _isBrochureLoading = true);

    // Format requirement details nicely to store in backend DB
    final formattedRequirement = "Date: $_brochureDateStr\nVehicle: $vehicle\nNote: Lead created via Brochure Sharing form.";

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    try {
      final response = await _apiService.post('add_lead.php', {
        'customer_name': name,
        'phone': phone,
        'requirement': formattedRequirement,
        if (currentUserId != null) 'assigned_dse': currentUserId,
        if (currentUserId != null) 'dse_id': currentUserId,
        if (currentUserId != null) 'created_by': currentUserId,
      });

      if (response['status'] == 'success') {
        if (!mounted) return;

        // 1. Send WhatsApp brochure via MSG91 Template in the background
        try {
          final cleanCustomer = name.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '_');
          final cleanVehicle = vehicle.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '_');
          
          String pdfUrl = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
          final matchingBrochure = _dbBrochures.firstWhere(
            (b) => b['vehicle_name'] == vehicle,
            orElse: () => <String, dynamic>{},
          );
          if (matchingBrochure.isNotEmpty && matchingBrochure['pdf_path'] != null) {
            final pdfPath = matchingBrochure['pdf_path'] as String;
            pdfUrl = "${ApiService.baseUrl.replaceAll('/api', '')}/$pdfPath";
          }
          
          await Msg91Service.sendWhatsAppBrochureTemplate(
            customerPhone: phone,
            pdfUrl: pdfUrl,
            filename: "${cleanCustomer}_${cleanVehicle}_Brochure.pdf",
            vehicleModel: vehicle,
            customerName: name,
          );
        } catch (e) {
          print("Error sending MSG91 WhatsApp brochure: $e");
        }

        _showBrochureSuccessDialog(phone, name, _brochureDateStr, vehicle);
        _brochureNameController.clear();
        _brochurePhoneController.clear();
        setState(() {
          _brochureSelectedVehicle = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _fetchBrochures() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBrochures = true;
    });
    try {
      final response = await _apiService.get('brochures.php');
      if (response != null && response['status'] == 'success') {
        final List<dynamic> data = response['data'] ?? [];
        setState(() {
          _dbBrochures = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print("Error fetching brochures from server: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBrochures = false;
        });
      }
    }
  }

  void _showBrochureSuccessDialog(String phone, String name, String dateStr, String vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(
          'Brochure lead has been added successfully.\n\nThe official brochure for "$vehicle" has been sent to $name via WhatsApp (MSG91).',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareBrochureWhatsApp(phone, name, vehicle, dateStr);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Send Manually'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({
    required String phone,
    required String name,
    required String quotationNo,
    required String dateStr,
    required String address,
    required String vehicle,
    required String exShowroom,
    required String discount,
    required String netInvoice,
    required String speedGovernor,
    required String insurance,
    required String roadTax,
    required String handling,
    required String accessories,
    required String fasTag,
    required String tcs,
    required String totalOnRoad,
    required String amountWords,
    required String notes,
    dynamic leadId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Lead Created!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Lead for "$name" has been successfully created.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The Proforma Invoice message and details have been sent directly to the customer via WhatsApp.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                final String pdfPath = "https://portal.hitechpragati.in/uploads/quotations/quotation_${quotationNo.replaceAll('/', '_')}.pdf";
                Share.share("Check out the generated Proforma Invoice PDF: $pdfPath");
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                foregroundColor: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.prefilledEnquiry != null) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _launchWhatsApp({
    required String phone,
    required String name,
    required String quotationNo,
    required String dateStr,
    required String address,
    required String vehicle,
    required String exShowroom,
    required String discount,
    required String netInvoice,
    required String speedGovernor,
    required String insurance,
    required String roadTax,
    required String handling,
    required String accessories,
    required String fasTag,
    required String tcs,
    required String totalOnRoad,
    required String amountWords,
    required String notes,
  }) async {
    final message = """
*HITECH MOTORS & AUTOMOBILES PVT. LTD.*
*QUOTATION CUM PROFORMA INVOICE*
--------------------------------------
*Quotation No:* $quotationNo
*Date:* $dateStr
*Customer Name:* $name
*Address:* ${address.isEmpty ? 'Not Provided' : address}
*Mobile:* $phone
--------------------------------------
*PARTICULARS & PRICING*
--------------------------------------
• *Model Destribution:* $vehicle
• *Ex Showroom Price:* ₹$exShowroom
• *Discount:* ₹$discount
• *Net Invoice Price:* ₹$netInvoice
• *Speed Governor:* ₹$speedGovernor
• *Insurance:* ₹$insurance
• *Road Tax / Reg. Charges:* ₹$roadTax
• *Handling Charge:* ₹$handling
• *Accessories:* ₹$accessories
• *FAS Tag:* ₹$fasTag
• *TCS:* ₹$tcs
--------------------------------------
*TOTAL ON ROAD PRICE:* ₹$totalOnRoad
*Amount in Words:* $amountWords
--------------------------------------
*Bank Details:*
*Bank Name:* AXIS BANK
*Account No:* 921020019284327
*IFSC CODE:* UTIB0001690
*Branch:* NEHRU NAGAR, BELAGAVI
--------------------------------------
*Notes:* ${notes.isEmpty ? 'N/A' : notes}

Best Regards,
*Hitech Motors & Automobiles*
""";

    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }



  void _shareBrochureWhatsApp(String phone, String name, String vehicle, String date) async {
    String pdfUrl = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
    final matchingBrochure = _dbBrochures.firstWhere(
      (b) => b['vehicle_name'] == vehicle,
      orElse: () => <String, dynamic>{},
    );
    if (matchingBrochure.isNotEmpty && matchingBrochure['pdf_path'] != null) {
      final pdfPath = matchingBrochure['pdf_path'] as String;
      pdfUrl = "${ApiService.baseUrl.replaceAll('/api', '')}/$pdfPath";
    }

    final message = """
*HITECH PRAGATI - OFFICIAL VEHICLE BROCHURE*
*Date:* $date
--------------------------------------
Dear $name,

Thank you for your interest in Hitech Pragati solutions. As requested, here is the official product brochure for:
*$vehicle*

*Brochure Link:* $pdfUrl

If you would like to request a customized quote or schedule a test drive, please let us know.

Best Regards,
*Hitech Pragati Team*
--------------------------------------
""";

    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.prefilledEnquiry != null ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enquiries & Leads'),
          bottom: const TabBar(
            indicatorColor: Color(0xFF3F51B5),
            labelColor: Color(0xFF3F51B5),
            unselectedLabelColor: Colors.grey,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(
                icon: Icon(Icons.question_answer_outlined),
                text: 'Enquiries',
              ),
              Tab(
                icon: Icon(Icons.person_add_alt_1_outlined),
                text: 'Leads',
              ),
              Tab(
                icon: Icon(Icons.menu_book_outlined),
                text: 'Brochures',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Enquiries Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.question_answer_outlined, size: 28, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text(
                        'New Enquiry',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a new corporate or individual vehicle purchase enquiry.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  
                  // Date (Pre-filled)
                  TextField(
                    controller: TextEditingController(
                      text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Enquiry Date (Auto)',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF3F51B5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Name
                  TextField(
                    controller: _enquiryNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mobile Number
                  TextField(
                    controller: _enquiryPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Alternate Mobile Number
                  TextField(
                    controller: _enquiryAlternatePhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Alternate Mobile Number (Optional)',
                      prefixIcon: const Icon(Icons.phone_iphone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Email (Optional)
                  TextField(
                    controller: _enquiryEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Customer Email (Optional)',
                      prefixIcon: const Icon(Icons.mail_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // GEOGRAPHY SECTION
                  const Row(
                    children: [
                      Icon(Icons.map_outlined, size: 20, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text(
                        'Location Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // State Searchable Picker Input
                  InkWell(
                    onTap: () {
                      _showSearchablePicker(
                        title: 'Select State',
                        items: _indiaStatesAndCities.keys.toList()..sort(),
                        selectedValue: _enquirySelectedState,
                        onSelected: (String val) {
                          setState(() {
                            _enquirySelectedState = val;
                            _enquirySelectedCity = null; // Reset city on state change
                          });
                        },
                      );
                    },
                    child: IgnorePointer(
                      child: TextField(
                        controller: TextEditingController(text: _enquirySelectedState ?? ''),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'State',
                          hintText: 'Tap to select State',
                          prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF3F51B5)),
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // City Searchable Picker Input
                  InkWell(
                    onTap: (_enquirySelectedState == null)
                        ? null
                        : () {
                            _showSearchablePicker(
                              title: 'Select City',
                              items: List<String>.from(_indiaStatesAndCities[_enquirySelectedState]!)..sort(),
                              selectedValue: _enquirySelectedCity,
                              onSelected: (String val) {
                                setState(() {
                                  _enquirySelectedCity = val;
                                });
                              },
                            );
                          },
                    child: IgnorePointer(
                      child: TextField(
                        controller: TextEditingController(text: _enquirySelectedCity ?? ''),
                        readOnly: true,
                        enabled: _enquirySelectedState != null,
                        decoration: InputDecoration(
                          labelText: 'City',
                          hintText: _enquirySelectedState == null
                              ? 'Select State first'
                              : 'Tap to select City',
                          prefixIcon: const Icon(Icons.location_city_outlined, color: Color(0xFF3F51B5)),
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: _enquirySelectedState == null ? Colors.grey.shade200 : Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pincode Field
                  TextField(
                    controller: _enquiryPincodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Pincode',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CATEGORIZATION & VEHICLE
                  const Row(
                    children: [
                      Icon(Icons.category_outlined, size: 20, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text(
                        'Segment & Vehicle Choice',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Segment Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _enquirySelectedSegment,
                    hint: const Text('Select Segment'),
                    decoration: InputDecoration(
                      labelText: 'Segment',
                      prefixIcon: const Icon(Icons.dashboard_customize_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _segments.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _enquirySelectedSegment = val;
                        _enquirySelectedVehicle = null; // Clear selected brand/model
                        _enquirySelectedBrand = 'Ashok Leyland'; // Auto set corporate brand name
                        _enquirySelectedVehicleUsage = null; // Clear vehicle usage selection
                        _enquirySelectedPrimaryApp = null; // Clear children applications
                        _enquirySelectedSecondaryApp = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Brand Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _enquirySelectedVehicle,
                    hint: const Text('Select Brand'),
                    decoration: InputDecoration(
                      labelText: 'Brand',
                      prefixIcon: const Icon(Icons.branding_watermark_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: (_enquirySelectedSegment == null)
                        ? []
                        : _segmentBrands[_enquirySelectedSegment]!.map((String model) {
                            return DropdownMenuItem<String>(
                              value: model,
                              child: Text(model, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _enquirySelectedVehicle = val;
                        _enquirySelectedPrimaryApp = null; // Reset children apps
                        _enquirySelectedSecondaryApp = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // PROFILE & USAGE
                  const Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text(
                        'Usage & Fleet Profile',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Vehicle Usage Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _enquirySelectedVehicleUsage,
                    hint: const Text('Select Vehicle Usage'),
                    decoration: InputDecoration(
                      labelText: 'Vehicle Usage',
                      prefixIcon: const Icon(Icons.route_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: (_enquirySelectedSegment == null)
                        ? []
                        : _segmentVehicleUsages[_enquirySelectedSegment]!.map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _enquirySelectedVehicleUsage = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Fleet Mix Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _enquirySelectedFleetMix,
                    hint: const Text('Select Fleet Mix'),
                    decoration: InputDecoration(
                      labelText: 'Fleet Mix',
                      prefixIcon: const Icon(Icons.group_work_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _fleetMixes.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _enquirySelectedFleetMix = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // APPLICATIONS SECTION
                  const Row(
                    children: [
                      Icon(Icons.assignment_outlined, size: 20, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text(
                        'Application Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Primary Application Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _enquirySelectedPrimaryApp,
                    hint: const Text('Select Primary Application'),
                    decoration: InputDecoration(
                      labelText: 'Primary Application',
                      prefixIcon: const Icon(Icons.star_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: (_enquirySelectedSegment == null)
                        ? []
                        : _segmentPrimaryApps[_enquirySelectedSegment]!.map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _enquirySelectedPrimaryApp = val;
                        _enquirySelectedSecondaryApp = null; // Clear secondary app when primary changes
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Secondary Application Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _enquirySelectedSecondaryApp,
                    hint: const Text('Select Secondary Application'),
                    decoration: InputDecoration(
                      labelText: 'Secondary Application',
                      prefixIcon: const Icon(Icons.star_half_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: (_enquirySelectedPrimaryApp == null)
                        ? []
                        : _primaryToSecondaryApps[_enquirySelectedPrimaryApp]!.map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _enquirySelectedSecondaryApp = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // ENQUIRY METADATA
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text(
                        'Enquiry Source & Scheduling',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Source of Enquiry Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _enquirySelectedSource,
                    hint: const Text('Select Source of Enquiry'),
                    decoration: InputDecoration(
                      labelText: 'Source of Enquiry',
                      prefixIcon: const Icon(Icons.link_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _sourcesOfEnquiry.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _enquirySelectedSource = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Enquiry Provider Mobile Number
                  TextField(
                    controller: _enquiryProviderPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Enquiry Provider Mobile Number',
                      prefixIcon: const Icon(Icons.contact_phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Follow Up Date Picker
                  TextField(
                    controller: _enquiryFollowUpDateController,
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF3F51B5),
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _enquiryFollowUpDateController.text = DateFormat('dd/MM/yyyy').format(picked);
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Follow Up Date',
                      hintText: 'Select Follow Up Date',
                      prefixIcon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF3F51B5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Coordinates TextField (Your Location)
                  TextField(
                    controller: TextEditingController(
                      text: (_userLatitude != null && _userLongitude != null)
                          ? "${_userLatitude!.toStringAsFixed(7)}, ${_userLongitude!.toStringAsFixed(7)}"
                          : (_isFetchingLocation ? "Fetching location..." : "Location not available"),
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Your Location (Latt, Long)',
                      prefixIcon: Icon(
                        Icons.my_location,
                        color: (_userLatitude != null && _userLongitude != null)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      suffixIcon: _isFetchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3F51B5)),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh, color: Color(0xFF3F51B5)),
                              tooltip: 'Refresh Location',
                              onPressed: _isFetchingLocation ? null : _fetchUserCoordinates,
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isEnquiryLoading ? null : _submitEnquiryLead,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F51B5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isEnquiryLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Enquiry', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),

            // Tab 2: Add Lead Form
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Information',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fill in the customer details below to create a new vehicle lead.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  
                  // Quotation Number (Auto)
                  TextField(
                    controller: TextEditingController(text: _quotationNo),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Quotation Number (Auto-generated)',
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3F51B5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date (Auto)
                  TextField(
                    controller: TextEditingController(text: _dateStr),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date (Auto-populated)',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF3F51B5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mobile Number
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Alternate Mobile Number
                  TextField(
                    controller: _alternatePhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Alternate Mobile Number (Optional)',
                      prefixIcon: const Icon(Icons.phone_iphone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Address
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Customer Address',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                   // Dropdown of Vehicles
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _selectedVehicle,
                    hint: const Text('Select Vehicle Variant'),
                    decoration: InputDecoration(
                      labelText: 'Vehicle Model',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _sortedVehicles.map((String vehicle) {
                      return DropdownMenuItem<String>(
                        value: vehicle,
                        child: Text(
                          vehicle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _selectedVehicle = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sexy Radio Selection for Lead Temperature Status
                  const Text(
                    'Lead Status / Temperature',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Cold Option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTempStatus = 'Cold';
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTempStatus == 'Cold'
                                  ? const Color(0xFFE3F2FD)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedTempStatus == 'Cold'
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: _selectedTempStatus == 'Cold'
                                  ? [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.ac_unit,
                                  color: _selectedTempStatus == 'Cold'
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade400,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cold',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTempStatus == 'Cold'
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Warm Option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTempStatus = 'Warm';
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTempStatus == 'Warm'
                                  ? const Color(0xFFFFF3E0)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedTempStatus == 'Warm'
                                    ? Colors.orange.shade600
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: _selectedTempStatus == 'Warm'
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wb_sunny_outlined,
                                  color: _selectedTempStatus == 'Warm'
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade400,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Warm',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTempStatus == 'Warm'
                                        ? Colors.orange.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Hot Option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTempStatus = 'Hot';
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTempStatus == 'Hot'
                                  ? const Color(0xFFFFEBEE)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedTempStatus == 'Hot'
                                    ? Colors.red.shade600
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: _selectedTempStatus == 'Hot'
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.whatshot,
                                  color: _selectedTempStatus == 'Hot'
                                      ? Colors.red.shade700
                                      : Colors.grey.shade400,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hot',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTempStatus == 'Hot'
                                        ? Colors.red.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Quotation Particulars Header
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text(
                        'Quotation Particulars (₹)',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Values are automatically computed in real-time.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Row 1: Ex-Showroom & Discount
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _exShowroomController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Ex Showroom Price Including GST',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Discount',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 2: Net Invoice Price & Speed Governor
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _netInvoiceController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Net invioce Price (Auto)',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _speedGovernorController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Speed Governor',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 3: Insurance & Road Tax / Registration
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _insuranceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Insurance',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _roadTaxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Road Tax / Registation Charges',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 4: Handling Charge & Accessories
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _handlingChargeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Handling Charge',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _accessoriesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Accessories',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 5: FAS Tag & TCS
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fasTagController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'FAS Tag',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tcsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'TCS',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Total On Road Price
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC5CAE9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total On Road Price',
                          style: TextStyle(fontSize: 13, color: Color(0xFF3F51B5), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _totalOnRoadController,
                          readOnly: true,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                          decoration: const InputDecoration(
                            prefixText: '₹ ',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount in words
                  TextField(
                    controller: _amountInWordsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Amount in words (Auto-generated)',
                      prefixIcon: const Icon(Icons.abc_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Notes (Optional)
                  TextField(
                    controller: _reqController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Extra Requirement Notes (Optional)',
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 10),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitLead,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F51B5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Lead', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),

            // Tab 3: Brochures Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share Brochure',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fill in the customer details below to send a vehicle brochure.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  
                  // Date (Auto)
                  TextField(
                    controller: TextEditingController(text: _brochureDateStr),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date (Auto-populated)',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF3F51B5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer Name
                  TextField(
                    controller: _brochureNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mobile Number
                  TextField(
                    controller: _brochurePhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                   // Dropdown of Vehicles
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                    value: _dbBrochures.any((b) => b['vehicle_name'] == _brochureSelectedVehicle)
                        ? _brochureSelectedVehicle
                        : null,
                    hint: _isLoadingBrochures
                        ? const Text('Loading variant list...')
                        : _dbBrochures.isEmpty
                            ? const Text('No variants configured. Add in settings.')
                            : const Text('Select Vehicle Variant'),
                    decoration: InputDecoration(
                      labelText: 'Vehicle Model',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _dbBrochures.map((b) => b['vehicle_name'] as String).map((String vehicle) {
                      return DropdownMenuItem<String>(
                        value: vehicle,
                        child: Text(
                          vehicle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _brochureSelectedVehicle = val;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isBrochureLoading ? null : _submitBrochureLead,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F51B5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isBrochureLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit & Share Brochure', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
