// lib/features/settings/screens/razorpay_gateway_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/sync_service.dart';

class RazorpayGatewayScreen extends ConsumerStatefulWidget {
  final String subId;
  const RazorpayGatewayScreen({super.key, required this.subId});

  @override
  ConsumerState<RazorpayGatewayScreen> createState() => _RazorpayGatewayScreenState();
}

class _RazorpayGatewayScreenState extends ConsumerState<RazorpayGatewayScreen> {
  String _selectedMethod = 'main'; // 'main', 'card', 'upi', 'netbanking', 'bank_login', 'success'
  bool _isProcessing = false;
  String _processingStatus = 'Processing Secure Payment...';
  
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _upiController = TextEditingController();
  final _bankSearchController = TextEditingController();

  String _selectedBank = '';
  String _selectedBankCode = '';
  String _searchQuery = '';
  bool _useBankQr = true;

  final List<Map<String, String>> _allBanks = [
    // Popular
    {'name': 'State Bank of India', 'code': 'sbi', 'type': 'Popular'},
    {'name': 'HDFC Bank', 'code': 'hdfc', 'type': 'Popular'},
    {'name': 'ICICI Bank', 'code': 'icici', 'type': 'Popular'},
    {'name': 'Axis Bank', 'code': 'axis', 'type': 'Popular'},
    {'name': 'Kotak Mahindra Bank', 'code': 'kotak', 'type': 'Popular'},
    {'name': 'Punjab National Bank', 'code': 'pnb', 'type': 'Popular'},
    
    // Public Sector Banks
    {'name': 'Bank of Baroda', 'code': 'bob', 'type': 'Public Sector'},
    {'name': 'Canara Bank', 'code': 'canara', 'type': 'Public Sector'},
    {'name': 'Union Bank of India', 'code': 'union', 'type': 'Public Sector'},
    {'name': 'Bank of India', 'code': 'boi', 'type': 'Public Sector'},
    {'name': 'Indian Bank', 'code': 'indian', 'type': 'Public Sector'},
    {'name': 'Central Bank of India', 'code': 'central', 'type': 'Public Sector'},
    {'name': 'Indian Overseas Bank', 'code': 'iob', 'type': 'Public Sector'},
    {'name': 'UCO Bank', 'code': 'uco', 'type': 'Public Sector'},
    {'name': 'Bank of Maharashtra', 'code': 'mahabank', 'type': 'Public Sector'},
    {'name': 'Punjab & Sind Bank', 'code': 'psb', 'type': 'Public Sector'},
    {'name': 'IDBI Bank', 'code': 'idbi', 'type': 'Public Sector'},

    // Private Sector Banks
    {'name': 'IndusInd Bank', 'code': 'indusind', 'type': 'Private Sector'},
    {'name': 'YES Bank', 'code': 'yes', 'type': 'Private Sector'},
    {'name': 'Federal Bank', 'code': 'federal', 'type': 'Private Sector'},
    {'name': 'IDFC First Bank', 'code': 'idfc', 'type': 'Private Sector'},
    {'name': 'Karnataka Bank', 'code': 'karnataka', 'type': 'Private Sector'},
    {'name': 'South Indian Bank', 'code': 'sib', 'type': 'Private Sector'},
    {'name': 'Karur Vysya Bank', 'code': 'kvb', 'type': 'Private Sector'},
    {'name': 'Bandhan Bank', 'code': 'bandhan', 'type': 'Private Sector'},
    {'name': 'RBL Bank', 'code': 'rbl', 'type': 'Private Sector'},
    {'name': 'City Union Bank', 'code': 'cub', 'type': 'Private Sector'},
    {'name': 'Tamilnad Mercantile Bank', 'code': 'tmb', 'type': 'Private Sector'},
    {'name': 'Jammu & Kashmir Bank', 'code': 'jkb', 'type': 'Private Sector'},
    {'name': 'CSB Bank', 'code': 'csb', 'type': 'Private Sector'},
    {'name': 'Dhanlaxmi Bank', 'code': 'dhanlaxmi', 'type': 'Private Sector'},

    // Cooperative Banks
    {'name': 'Saraswat Cooperative Bank', 'code': 'saraswat', 'type': 'Cooperative'},
    {'name': 'Cosmos Cooperative Bank', 'code': 'cosmos', 'type': 'Cooperative'},
    {'name': 'SVC Cooperative Bank (Shamrao Vithal)', 'code': 'svc', 'type': 'Cooperative'},
    {'name': 'TJSB Sahakari Bank', 'code': 'tjsb', 'type': 'Cooperative'},
    {'name': 'Abhyudaya Cooperative Bank', 'code': 'abhyudaya', 'type': 'Cooperative'},
    {'name': 'Bharat Cooperative Bank', 'code': 'bharat', 'type': 'Cooperative'},
    {'name': 'Janata Sahakari Bank', 'code': 'janata', 'type': 'Cooperative'},

    // Regional Rural / Gramin Banks
    {'name': 'Kerala Gramin Bank', 'code': 'kgb', 'type': 'Gramin / Rural'},
    {'name': 'Andhra Pragathi Grameena Bank', 'code': 'apgb', 'type': 'Gramin / Rural'},
    {'name': 'Karnataka Vikas Grameena Bank', 'code': 'kvgb', 'type': 'Gramin / Rural'},
    {'name': 'Baroda Rajasthan Kshetriya Gramin Bank', 'code': 'brkgb', 'type': 'Gramin / Rural'},
    {'name': 'Saurashtra Gramin Bank', 'code': 'sgb', 'type': 'Gramin / Rural'},
    {'name': 'Prathama UP Gramin Bank', 'code': 'pupgb', 'type': 'Gramin / Rural'},

    // Foreign Banks
    {'name': 'Citibank', 'code': 'citi', 'type': 'Foreign'},
    {'name': 'HSBC Bank', 'code': 'hsbc', 'type': 'Foreign'},
    {'name': 'Standard Chartered Bank', 'code': 'sc', 'type': 'Foreign'},
    {'name': 'DBS Bank', 'code': 'dbs', 'type': 'Foreign'},
    {'name': 'Deutsche Bank', 'code': 'deutsche', 'type': 'Foreign'},
  ];

  @override
  void initState() {
    super.initState();
    _bankSearchController.addListener(() {
      setState(() {
        _searchQuery = _bankSearchController.text;
      });
    });
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    _upiController.dispose();
    _bankSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF0B72E7);
    final razorpayDark = const Color(0xFF092240);

    return Scaffold(
      backgroundColor: isDark ? razorpayDark : Colors.grey.shade900,
      body: Center(
        child: Container(
          width: 480,
          height: 680,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF112A4A) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 8,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [razorpayDark, const Color(0xFF0F3260)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RAZORPAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trusted by 50L+ businesses',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text('Amount to Pay', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          SizedBox(height: 2),
                          Text('₹499.00', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                
                // Sub Header / Security Shield banner
                Container(
                  color: primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Secured by Razorpay • PCI-DSS Compliant',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        'ID: ${widget.subId.substring(0, 10).toUpperCase()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                
                // Main Body Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildCurrentView(isDark, primaryBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(bool isDark, Color primaryBlue) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              strokeWidth: 4,
            ),
            const SizedBox(height: 24),
            Text(
              _processingStatus,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please do not close or refresh this screen.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    switch (_selectedMethod) {
      case 'card':
        return _buildCardView(isDark, primaryBlue);
      case 'upi':
        return _buildUpiView(isDark, primaryBlue);
      case 'netbanking':
        return _buildNetbankingView(isDark, primaryBlue);
      case 'bank_login':
        return _buildBankLoginView(isDark, primaryBlue);
      case 'success':
        return _buildSuccessView(isDark);
      case 'main':
      default:
        return _buildMainOptions(isDark, primaryBlue);
    }
  }

  Widget _buildMainOptions(bool isDark, Color primaryBlue) {
    final titleStyle = TextStyle(
      color: isDark ? Colors.white60 : Colors.black54,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CARDS & UPI', style: titleStyle),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.credit_card_rounded,
          title: 'Card / Debit Card',
          subtitle: 'Visa, MasterCard, RuPay',
          onTap: () => setState(() => _selectedMethod = 'card'),
          isDark: isDark,
        ),
        _buildOptionTile(
          icon: Icons.qr_code_2_rounded,
          title: 'UPI / QR',
          subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
          onTap: () => setState(() => _selectedMethod = 'upi'),
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        Text('OTHER PAYMENT METHODS', style: titleStyle),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.account_balance_rounded,
          title: 'Netbanking',
          subtitle: 'All major, cooperative & rural Indian banks',
          onTap: () => setState(() => _selectedMethod = 'netbanking'),
          isDark: isDark,
        ),
        const Spacer(),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel Payment',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildCardView(bool isDark, Color primaryBlue) {
    String cardNum = _cardNumberController.text.replaceAll(' ', '');
    String cardLogo = 'CARD';
    if (cardNum.startsWith('4')) {
      cardLogo = 'VISA';
    } else if (cardNum.startsWith('5')) {
      cardLogo = 'MASTERCARD';
    } else if (cardNum.startsWith('6')) {
      cardLogo = 'RUPAY';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => setState(() => _selectedMethod = 'main'),
            ),
            const Text(
              'Card Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Interactive Credit Card Widget
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3057), Color(0xFF00587A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.contactless_outlined, color: Colors.white, size: 28),
                  Text(
                    cardLogo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              Text(
                _cardNumberController.text.isEmpty
                    ? '•••• •••• •••• ••••'
                    : _formatCardNumber(_cardNumberController.text),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CARD HOLDER',
                        style: TextStyle(color: Colors.white54, fontSize: 8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _cardHolderController.text.isEmpty
                            ? 'YOUR NAME'
                            : _cardHolderController.text.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'EXPIRES',
                        style: TextStyle(color: Colors.white54, fontSize: 8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _cardExpiryController.text.isEmpty ? 'MM/YY' : _cardExpiryController.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Expanded(
          child: ListView(
            shrinkWrap: true,
            children: [
              TextField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '4312 9012 3412 8890',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                  counterText: '',
                ),
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cardHolderController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Card Holder Name',
                  hintText: 'JOHN DOE',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cardExpiryController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        hintText: 'MM/YY',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cardCvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startProcessingPayment,
            child: const Text('PAY NOW ₹499.00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )
      ],
    );
  }

  String _formatCardNumber(String input) {
    input = input.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      buffer.write(input[i]);
      int index = i + 1;
      if (index % 4 == 0 && index != input.length) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  Widget _buildUpiView(bool isDark, Color primaryBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => setState(() => _selectedMethod = 'main'),
            ),
            const Text('UPI Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _upiController,
          decoration: const InputDecoration(
            labelText: 'Enter UPI ID',
            hintText: 'username@okaxis',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'OR Scan QR Code with any UPI App',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  
                  // Professional QR Code Widget with Razorpay Emblem
                  const ProfessionalQRCodeWidget(size: 180),
                  
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment_rounded, color: primaryBlue, size: 14),
                      const SizedBox(width: 6),
                      const Text(
                        'BHIM • Google Pay • PhonePe • Paytm',
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startProcessingPayment,
            child: const Text('VERIFY & PAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )
      ],
    );
  }

  Widget _buildNetbankingView(bool isDark, Color primaryBlue) {
    // Filter banks
    final filteredBanks = _allBanks.where((bank) {
      final name = bank['name']!.toLowerCase();
      final type = bank['type']!.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || type.contains(query);
    }).toList();

    // Split filtered list by Type
    final popular = filteredBanks.where((b) => b['type'] == 'Popular').toList();
    final publicSec = filteredBanks.where((b) => b['type'] == 'Public Sector').toList();
    final privateSec = filteredBanks.where((b) => b['type'] == 'Private Sector').toList();
    final cooperative = filteredBanks.where((b) => b['type'] == 'Cooperative').toList();
    final gramin = filteredBanks.where((b) => b['type'] == 'Gramin / Rural').toList();
    final foreign = filteredBanks.where((b) => b['type'] == 'Foreign').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => setState(() => _selectedMethod = 'main'),
            ),
            const Text('Netbanking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bankSearchController,
          decoration: InputDecoration(
            hintText: 'Search your bank...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _bankSearchController.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        
        Expanded(
          child: ListView(
            children: [
              if (popular.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Popular Banks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: popular.length,
                  itemBuilder: (context, index) {
                    final bank = popular[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedBank = bank['name']!;
                          _selectedBankCode = bank['code']!;
                          _selectedMethod = 'bank_login';
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade800,
                              radius: 14,
                              child: Text(
                                bank['code']!.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                bank['name']!,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              if (publicSec.isNotEmpty) ...[
                _buildBankCategoryHeader('Public Sector Banks'),
                ...publicSec.map((b) => _buildBankTile(b, isDark)),
                const SizedBox(height: 8),
              ],
              if (privateSec.isNotEmpty) ...[
                _buildBankCategoryHeader('Private Sector Banks'),
                ...privateSec.map((b) => _buildBankTile(b, isDark)),
                const SizedBox(height: 8),
              ],
              if (cooperative.isNotEmpty) ...[
                _buildBankCategoryHeader('Cooperative Banks'),
                ...cooperative.map((b) => _buildBankTile(b, isDark)),
                const SizedBox(height: 8),
              ],
              if (gramin.isNotEmpty) ...[
                _buildBankCategoryHeader('Regional Rural / Gramin Banks'),
                ...gramin.map((b) => _buildBankTile(b, isDark)),
                const SizedBox(height: 8),
              ],
              if (foreign.isNotEmpty) ...[
                _buildBankCategoryHeader('Foreign Banks'),
                ...foreign.map((b) => _buildBankTile(b, isDark)),
                const SizedBox(height: 8),
              ],
              
              if (filteredBanks.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No banks match your search query', style: TextStyle(color: Colors.grey)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
      ),
    );
  }

  Widget _buildBankTile(Map<String, String> bank, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade400,
        radius: 12,
        child: Text(
          bank['name']!.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(bank['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: () {
        setState(() {
          _selectedBank = bank['name']!;
          _selectedBankCode = bank['code']!;
          _selectedMethod = 'bank_login';
        });
      },
    );
  }

  Widget _buildBankLoginView(bool isDark, Color primaryBlue) {
    final bankColor = _getBankColor(_selectedBankCode);
    final bankAcronym = _selectedBankCode.isEmpty ? 'BANK' : _selectedBankCode.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => setState(() => _selectedMethod = 'netbanking'),
            ),
            Expanded(
              child: Text(
                _selectedBank,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Authorization Toggle Tabs
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _useBankQr = true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _useBankQr ? bankColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Scan Bank QR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _useBankQr ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _useBankQr = false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_useBankQr ? bankColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Manual Login',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !_useBankQr ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _useBankQr
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Scan with your $bankAcronym mobile banking app to authorize',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        ProfessionalQRCodeWidget(
                          size: 170,
                          label: bankAcronym,
                          centerColor: bankColor,
                          centerTextColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.security_rounded, color: bankColor, size: 12),
                            const SizedBox(width: 6),
                            const Text(
                              'Authorized Secure Netbanking Gateway',
                              style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: const [
                    Text(
                      'SECURE INTERNET BANKING',
                      style: TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Online Banking Customer ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'IPIN / Login Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _useBankQr ? bankColor : const Color(0xFF007E33),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startProcessingPayment,
            child: Text(
              _useBankQr ? 'CONFIRM AND AUTHORIZE' : 'AUTHORIZE PAYMENT',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        )
      ],
    );
  }

  Color _getBankColor(String code) {
    switch (code.toLowerCase()) {
      case 'sbi': return const Color(0xFF00BFFF);
      case 'hdfc': return const Color(0xFF004C8F);
      case 'icici': return const Color(0xFFE56A15);
      case 'axis': return const Color(0xFF900A3F);
      case 'kotak': return const Color(0xFFEE1C25);
      case 'pnb': return const Color(0xFF800000);
      case 'bob': return const Color(0xFFFF6600);
      case 'canara': return const Color(0xFF007EC3);
      case 'union': return const Color(0xFFD21F3C);
      case 'boi': return const Color(0xFF0054A6);
      case 'indian': return const Color(0xFF007DC5);
      case 'yes': return const Color(0xFF005691);
      case 'federal': return const Color(0xFF003087);
      case 'idfc': return const Color(0xFF9E1F22);
      case 'citi': return const Color(0xFF003B70);
      case 'hsbc': return const Color(0xFFDB0011);
      default: return const Color(0xFF092240);
    }
  }

  Widget _buildSuccessView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF007E33), size: 90),
          const SizedBox(height: 24),
          const Text(
            'Payment Successful!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF007E33)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your Pro subscription is now active.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context); // Close gateway
              },
              child: const Text('Return to BizNext', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  void _startProcessingPayment() {
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Processing Secure Payment...';
    });
    Future.delayed(const Duration(seconds: 2), () async {
      final subService = ref.read(subscriptionServiceProvider);
      // Upgrade database locally
      await subService.setTier('pro');
      
      if (mounted) {
        setState(() {
          _processingStatus = 'Syncing all data from internet database...';
        });
      }

      // Sync all data from the internet database
      try {
        await SyncService().syncNow("dummy_token_12345");
      } catch (e) {
        debugPrint("Sync error during checkout: $e");
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedMethod = 'success';
        });
      }
    });
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(icon, color: const Color(0xFF0B72E7), size: 28),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ),
    );
  }
}

class ProfessionalQRCodeWidget extends StatelessWidget {
  final double size;
  final String label;
  final Color centerColor;
  final Color centerTextColor;

  const ProfessionalQRCodeWidget({
    super.key,
    this.size = 180,
    this.label = 'R',
    this.centerColor = const Color(0xFF092240),
    this.centerTextColor = const Color(0xFF0B72E7),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background simulation of QR patterns
          CustomPaint(
            size: Size(size - 24, size - 24),
            painter: QRPainter(color: centerColor),
          ),
          // Center Logo Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: centerColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: centerTextColor,
                fontSize: label.length > 2 ? 10 : 13,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QRPainter extends CustomPainter {
  final Color color;
  QRPainter({this.color = const Color(0xFF092240)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double cellSize = size.width / 15;

    // Helper to draw corner position detection patterns
    void drawPositionMarker(double x, double y) {
      // Outer 7x7 cell block
      canvas.drawRect(Rect.fromLTWH(x, y, cellSize * 7, cellSize * 7), paint);
      // Inner white 5x5 cell block
      canvas.drawRect(
        Rect.fromLTWH(x + cellSize, y + cellSize, cellSize * 5, cellSize * 5),
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );
      // Center solid 3x3 cell block
      canvas.drawRect(
        Rect.fromLTWH(x + cellSize * 2, y + cellSize * 2, cellSize * 3, cellSize * 3),
        paint,
      );
    }

    // Top-Left
    drawPositionMarker(0, 0);
    // Top-Right
    drawPositionMarker(size.width - cellSize * 7, 0);
    // Bottom-Left
    drawPositionMarker(0, size.height - cellSize * 7);

    // Draw static deterministic QR code blocks
    final matrix = [
      [0,0,0,0,0,0,0,0,1,1,0,1,1,1,1],
      [0,0,0,0,0,0,0,0,1,0,0,1,0,0,0],
      [0,0,0,0,0,0,0,0,0,1,1,0,0,1,1],
      [0,0,0,0,0,0,0,0,1,0,1,1,0,1,0],
      [0,0,0,0,0,0,0,0,0,0,1,1,0,0,1],
      [0,0,0,0,0,0,0,0,1,1,0,1,0,1,0],
      [0,0,0,0,0,0,0,0,0,1,1,0,1,1,1],
      [0,0,0,0,0,0,0,0,1,0,0,1,0,0,1],
      [1,1,0,1,0,1,0,1,0,0,0,0,0,0,0],
      [1,0,1,1,0,0,1,0,0,0,0,0,0,0,0],
      [0,1,1,0,1,1,0,0,0,0,0,0,0,0,0],
      [1,1,0,1,1,0,1,0,0,0,0,0,0,0,0],
      [0,0,1,0,1,1,0,0,0,0,0,0,0,0,0],
      [1,1,0,1,0,0,1,0,0,0,0,0,0,0,0],
      [1,0,1,1,1,1,0,0,0,0,0,0,0,0,0],
    ];

    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        // Skip corner spaces
        if (r < 8 && c < 8) continue;
        if (r < 8 && c > 7) continue;
        if (r > 7 && c < 8) continue;
        
        // Skip center logo space
        if (r >= 6 && r <= 8 && c >= 6 && c <= 8) continue;

        if (matrix[r][c] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }

    // Additional scattered random dots for realism
    for (int r = 8; r < 15; r++) {
      for (int c = 8; c < 15; c++) {
        if ((r + c) % 3 == 0 || (r * c) % 5 == 2) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

