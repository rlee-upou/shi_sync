import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// ==========================================
// SUPABASE CONFIGURATION
// Replace these placeholders with your actual project credentials
// ==========================================
const String SUPABASE_URL = 'https://qjpcoeeqbexpfraqaxjq.supabase.co';
const String SUPABASE_ANON_KEY = 'sb_publishable_gTEwSJV56GvrPBQfoytsfg_E5OYffpR';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );

  runApp(const ShiApp());
}

class ShiApp extends StatelessWidget {
  const ShiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHI-Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF),
          primary: const Color(0xFF1E40AF),
          secondary: const Color(0xFF0D9488),
          surface: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif', 
      ),
      home: const MainGatekeeper(),
    );
  }
}

// ==========================================
// TACTILE UI COMPONENTS (Design System)
// ==========================================

class AnimatedTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final bool disabled;

  const AnimatedTactileButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.disabled = false,
  });

  @override
  State<AnimatedTactileButton> createState() => _AnimatedTactileButtonState();
}

class _AnimatedTactileButtonState extends State<AnimatedTactileButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.disabled ? null : _controller.forward(),
      onTapUp: (_) => widget.disabled ? null : _controller.reverse(),
      onTapCancel: () => widget.disabled ? null : _controller.reverse(),
      onTap: widget.disabled ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.disabled ? const Color(0xFFE2E8F0) : (widget.color ?? const Color(0xFF1E40AF)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.disabled ? null : [
              BoxShadow(
                color: (widget.color ?? const Color(0xFF1E40AF)).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class TactileCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;

  const TactileCard({super.key, required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (accentColor ?? const Color(0xFF64748B)).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }
}

// ==========================================
// CORE APP SCREENS
// ==========================================

class MainGatekeeper extends StatefulWidget {
  const MainGatekeeper({super.key});

  @override
  State<MainGatekeeper> createState() => _MainGatekeeperState();
}

class _MainGatekeeperState extends State<MainGatekeeper> {
  bool _isLoading = true;
  String? _uuid;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uuid = prefs.getString('resident_uuid');
      _hasPermissions = prefs.getBool('health_permissions_granted') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_uuid != null && _hasPermissions) {
      return const DashboardScreen();
    } else if (_uuid != null) {
      return const PermissionScreen();
    } else {
      return const SetupScreen();
    }
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _barangayId = 1;
  String _ageGroup = '18-24';
  bool _hasConsented = false;

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final newUuid = const Uuid().v4();
    
    await prefs.setString('resident_uuid', newUuid);
    await prefs.setInt('resident_barangay_id', _barangayId);
    await prefs.setString('resident_age', _ageGroup);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PermissionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sync, color: Color(0xFF1E40AF), size: 32),
              ),
              const SizedBox(height: 24),
              const Text('Onboarding', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.5)),
              const Text('SHI-Sync', 
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.1)),
              const SizedBox(height: 16),
              const Text('Help build a healthier community in Quezon City by anonymously sharing your activity baseline.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.4)),
              const SizedBox(height: 32),
              
              TactileCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RESIDENT LOCATION', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _barangayId,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Bgy. UP Campus', style: TextStyle(fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 2, child: Text('Bgy. Fairview', style: TextStyle(fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 3, child: Text('Bgy. Payatas', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) => setState(() => _barangayId = val!),
                    ),
                    const Divider(height: 32),
                    const Text('AGE BRACKET', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _ageGroup,
                      underline: const SizedBox(),
                      items: ['18-24', '25-34', '35-44', '45-54', '55-64', '65+'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)));
                      }).toList(),
                      onChanged: (val) => setState(() => _ageGroup = val!),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _hasConsented,
                      activeColor: const Color(0xFF1E40AF),
                      onChanged: (val) => setState(() => _hasConsented = val!),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _hasConsented = !_hasConsented),
                        child: const Text(
                          'I consent to share my anonymized data (RA 10173). No GPS or personal names are collected.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              AnimatedTactileButton(
                disabled: !_hasConsented,
                onPressed: _completeSetup,
                child: const Text('Initialize Sync', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isSyncing = false;
  bool _showError = false;

  // ✅ ADD THIS ENTIRE BLOCK:
  @override
  void initState() {
    super.initState();
    // Initialize the native permission bridge now that the UI is mounted
    Health().configure(); 
  }

  Future<void> _requestAndSync() async {
    setState(() {
      _isSyncing = true;
      _showError = false;
    });
    
    try {
      Health health = Health();
      var types = [HealthDataType.STEPS, HealthDataType.WORKOUT];

      // Explicitly tell the plugin we only want READ access
      var permissions = [HealthDataAccess.READ, HealthDataAccess.READ]; 
      
      // Pass the permissions array to the authorization request
      bool requested = await health.requestAuthorization(types, permissions: permissions);

      
      if (requested) {
        final prefs = await SharedPreferences.getInstance();
        
        var now = DateTime.now();
        var sevenDaysAgo = now.subtract(const Duration(days: 7));
        
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: sevenDaysAgo, 
          endTime: now, 
          types: types
        );
        
// ==========================================
        // EDGE COMPUTING: ROLLING AVERAGE LOGIC
        // ==========================================
        debugPrint("\n=== SHI-SYNC DATA PIPELINE START ===");
        debugPrint("1. Raw data points pulled from Health Connect: ${healthData.length}");
        
        // STEP A & B: Custom Fingerprint Deduplication & Processing
        List<HealthDataPoint> rawSteps = healthData.where((p) => p.type == HealthDataType.STEPS).toList();
        
        // 1. Create a Map to automatically crush duplicates based on their unique fingerprint
        Map<String, int> uniqueStepChunks = {};
        
        for (var p in rawSteps) {
          var stepsObject = p.value as NumericHealthValue;
          int val = stepsObject.numericValue.toInt();
          
          // 2. Generate the unique fingerprint: "StartTime_EndTime_StepCount"
          String fingerprint = "${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}_$val";
          
          // 3. Store it. Maps cannot have duplicate keys, so exact clones overwrite each other!
          uniqueStepChunks[fingerprint] = val;
        }

        debugPrint("2. Step Deduplication: Reduced ${rawSteps.length} raw points to ${uniqueStepChunks.length} unique points.");

        // 4. Group the cleaned, unique chunks by day
        Map<String, int> dailySteps = {};
        int totalMins = 0;

        // We iterate over the raw data again just to match the unique fingerprints back to their dates
        for (var p in rawSteps) {
          var stepsObject = p.value as NumericHealthValue;
          int val = stepsObject.numericValue.toInt();
          String fingerprint = "${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}_$val";
          
          // If this fingerprint is still in our unique map, process it and then remove it so we don't count it twice
          if (uniqueStepChunks.containsKey(fingerprint)) {
            String dateKey = DateFormat('yyyy-MM-dd').format(p.dateFrom);
            dailySteps[dateKey] = (dailySteps[dateKey] ?? 0) + val;
            
            // Remove it from the map so future clones in the loop are ignored
            uniqueStepChunks.remove(fingerprint);
            
            debugPrint("Date: $dateKey | Steps: $val | Status: KEPT");
          } else {
            // debugPrint("Date: ${DateFormat('yyyy-MM-dd').format(p.dateFrom)} | Steps: $val | Status: DROPPED (Clone)");
          }
        }

        // STEP C: Process Workouts
        List<HealthDataPoint> workoutData = healthData.where((p) => p.type == HealthDataType.WORKOUT).toList();
        for (var p in workoutData) {
          int durationMins = p.dateTo.difference(p.dateFrom).inMinutes;
          totalMins += durationMins;
          debugPrint("   -> Workout Found: ${DateFormat('MMM dd').format(p.dateFrom)} ($durationMins mins)");
        }

        // STEP D: Calculate True Averages
        debugPrint("\n3. --- Daily Step Breakdown ---");
        int totalSteps7Days = 0;
        
        // Sort the dates so they print in chronological order in the terminal
        var sortedDates = dailySteps.keys.toList()..sort();
        for (var dateKey in sortedDates) {
          int steps = dailySteps[dateKey]!;
          debugPrint("   Date: $dateKey | Steps: $steps");
          totalSteps7Days += steps;
        }

        // Strict 7-day average (Divide by 7 to get a true weekly baseline, even if they had 0 steps some days)
        int avgSteps = (totalSteps7Days / 7).round();
        
        debugPrint("\n4. --- Final Baseline Calculations ---");
        debugPrint("   Total Steps (7 Days): $totalSteps7Days");
        debugPrint("   Calculated Daily Average ($totalSteps7Days / 7): $avgSteps steps/day");
        debugPrint("   Total Workout Minutes (7 Days): $totalMins mins");
        debugPrint("=== SHI-SYNC DATA PIPELINE END ===\n");

        // Save to device storage
        await prefs.setBool('health_permissions_granted', true);
        await prefs.setInt('avg_steps', avgSteps);
        await prefs.setInt('avg_mins', totalMins);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        setState(() => _showError = true);
      }
    } catch (e) {
      debugPrint("Health error: $e");
      setState(() => _showError = true);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, size: 48, color: Color(0xFFF43F5E)),
              ),
              const SizedBox(height: 32),
              const Text('Connect Device', 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Text(
                _showError 
                  ? 'Permission Required: SHI-Sync cannot establish your activity baseline without access to Google Health Connect.'
                  : 'Allow SHI-Sync to read your Step and Exercise data to help establish a community health baseline.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),
              AnimatedTactileButton(
                onPressed: _isSyncing ? null : _requestAndSync,
                child: _isSyncing 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Grant Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              if (_showError)
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const SetupScreen()));
                  },
                  child: const Text('Back to Setup', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _steps = 0;
  int _mins = 0;
  String _uuid = '';
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _steps = prefs.getInt('avg_steps') ?? 0;
      _mins = prefs.getInt('avg_mins') ?? 0;
      _uuid = prefs.getString('resident_uuid') ?? '';
    });
  }

  Future<void> _pushToSupabase() async {
    setState(() => _isSyncing = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final barangayId = prefs.getInt('resident_barangay_id') ?? 1;
      final ageGroup = prefs.getString('resident_age') ?? '25-34';
      
      // 1. Ensure Resident Profile Exists
      await Supabase.instance.client
          .from('residents')
          .upsert({
            'id': _uuid,
            'barangay_id': barangayId,
            'age_group': ageGroup,
            'primary_source': 'FIELD_AGENT',
          });

      // 2. Push Activity Log
      await Supabase.instance.client
          .from('activity_logs')
          .insert({
            'resident_id': _uuid,
            'source_type': 'HEALTH_CONNECT',
            'daily_steps': _steps,
            'weekly_exercise_mins': _mins,
            'local_timestamp': DateTime.now().toIso8601String(),
            'is_synced': true,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity baseline synced successfully!'), backgroundColor: Color(0xFF0D9488)),
        );
      }
    } catch (e) {
      debugPrint("Supabase Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync failed. Check connection.'), backgroundColor: Color(0xFFE11D48)),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('SHI-Sync', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.shield_outlined, color: Color(0xFF0D9488)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF0D9488), shape: BoxShape.circle)),
                ),
                const SizedBox(width: 8),
                const Text('Background Active', 
                  style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 24),
            
            const Text('Your 7-Day Baseline', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text('Averages calculated from your phone sensors.', 
              style: TextStyle(color: Color(0xFF64748B))),
            
            const SizedBox(height: 32),
            
            TactileCard(
              accentColor: const Color(0xFF1E40AF),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DAILY STEPS', 
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                      Text(NumberFormat('#,###').format(_steps), 
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF))),
                    ],
                  ),
                  const Divider(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('WEEKLY EXERCISE', 
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                      Text('$_mins mins', 
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0D9488))),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E40AF).withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  const Text('ANONYMOUS IDENTIFIER', 
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF), letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(_uuid, 
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
            AnimatedTactileButton(
              onPressed: _isSyncing ? null : _pushToSupabase,
              color: const Color(0xFF0D9488),
              child: _isSyncing 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Manual Push to Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
            ),
            
            const SizedBox(height: 12),
            
            Center(
              child: TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset Profile?', style: TextStyle(fontWeight: FontWeight.w900)),
                      content: const Text('This will generate a NEW anonymous ID. All future data will be attributed to your new demographics in the city database.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const SetupScreen()),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Update Demographics & Profile', 
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}