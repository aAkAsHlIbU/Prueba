import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:incampus/config/razorpay_config.dart';

class VerificationScreen extends StatefulWidget {
  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late Razorpay _razorpay;
  bool _isVerified = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkVerificationStatus();
  }

  void _checkVerificationStatus() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/$userId');
      DatabaseEvent event = await userRef.once();
      if (event.snapshot.value != null) {
        final userData = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _isVerified = userData['isVerified'] ?? false;
          _isLoading = false;
        });
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _updateVerificationStatus();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('External wallet selected: ${response.walletName}')),
    );
  }

  void _updateVerificationStatus() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/$userId');
      await userRef.update({
        'isVerified': true,
        'verificationTimestamp': ServerValue.timestamp,
      });
      setState(() {
        _isVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Congratulations! You are now verified.')),
      );
    }
  }

  void _startPayment() {
    var options = {
      'key': RazorpayConfig.keyId,
      'amount': 1000, // Amount in paise (10 rupees)
      'name': 'InCampus Verification',
      'description': 'Verification Fee',
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber,
        'email': FirebaseAuth.instance.currentUser?.email
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        primaryColor: Colors.blueGrey[800],
        scaffoldBackgroundColor: Colors.grey[900],
        cardColor: Colors.grey[850],
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.blueAccent,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Get Verified'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _isVerified ? Icons.verified : Icons.verified_outlined,
                        size: 100,
                        color: _isVerified ? Colors.blueAccent : Colors.grey,
                      ),
                      SizedBox(height: 24),
                      Text(
                        _isVerified ? 'You are Verified!' : 'Get Verified',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 24),
                      Card(
                        elevation: 4,
                        color: Colors.grey[850],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Advantages of being verified:',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              SizedBox(height: 16),
                              _buildAdvantageItem(
                                  Icons.trending_up, 'Increased credibility'),
                              _buildAdvantageItem(Icons.visibility,
                                  'Higher visibility in search results'),
                              _buildAdvantageItem(
                                  Icons.star, 'Access to exclusive features'),
                              _buildAdvantageItem(Icons.support_agent,
                                  'Priority customer support'),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      if (!_isVerified)
                        Card(
                          elevation: 4,
                          color: Colors.grey[850],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  'Verification fee: ₹10',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _startPayment,
                                  child: Text('Pay and Get Verified',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAdvantageItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          SizedBox(width: 12),
          Text(text, style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}
