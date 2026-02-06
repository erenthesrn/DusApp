// lib/screens/focus_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/focus_service.dart'; // Oluşturduğumuz servisi çekiyoruz

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  // Servise erişim
  final FocusService _focusService = FocusService.instance;

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder kullanarak servis her güncellendiğinde (her saniye)
    // sadece gerekli yerleri yeniden çizdiriyoruz.
    return AnimatedBuilder(
      animation: _focusService,
      builder: (context, child) {
        
        // NOT: Artık burada "SÜRE BİTİŞ KONTROLÜ" yapmamıza gerek yok.
        // FocusService içindeki global pop-up mekanizması her şeyi hallediyor.

        // Yüzde hesaplama
        double percent = _focusService.totalTimeInSeconds > 0
            ? (_focusService.remainingSeconds / _focusService.totalTimeInSeconds)
            : 0.0;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F9FF),
          appBar: AppBar(
            title: const Text("Odak Modu 🎯"),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87,
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // --- 1. SAYAÇ GÖSTERGESİ ---
                GestureDetector(
                  onTap: _showDurationPicker,
                  child: CircularPercentIndicator(
                    radius: 140.0,
                    lineWidth: 15.0,
                    animation: true,
                    animateFromLastPercent: true,
                    percent: percent.clamp(0.0, 1.0),
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(_focusService.remainingSeconds),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 50.0,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        Text(
                          _focusService.isRunning
                              ? "Odaklanıyor..."
                              : (_focusService.isPaused ? "Duraklatıldı" : "Süreyi Ayarla"),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16.0,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: Colors.grey.shade200,
                    progressColor: _focusService.remainingSeconds < 60
                        ? Colors.red
                        : const Color(0xFF1565C0),
                  ),
                ),

                // --- 2. HIZLI SEÇİM BUTONLARI ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Hızlı Süre Seçimi",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTimeChip("Pomodoro", 25),
                          _buildTimeChip("Etüt", 50),
                          _buildTimeChip("Blok", 60),
                          ActionChip(
                            label: const Text("Özel"),
                            avatar: const Icon(Icons.timer, size: 16, color: Colors.black87),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade200),
                            onPressed: _showDurationPicker,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- 3. KONTROL BUTONLARI ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_focusService.isRunning && !_focusService.isPaused)
                      _buildControlBtn(
                          icon: Icons.play_arrow_rounded,
                          label: "Başlat",
                          color: const Color(0xFF1565C0),
                          onTap: _focusService.startTimer)
                    else if (_focusService.isRunning)
                      _buildControlBtn(
                          icon: Icons.pause_rounded,
                          label: "Duraklat",
                          color: Colors.orange,
                          onTap: _focusService.pauseTimer)
                    else if (_focusService.isPaused)
                      _buildControlBtn(
                          icon: Icons.play_arrow_rounded,
                          label: "Devam Et",
                          color: Colors.green,
                          onTap: _focusService.resumeTimer),
                    
                    const SizedBox(width: 20),
                    
                    if (_focusService.remainingSeconds != _focusService.totalTimeInSeconds)
                      _buildControlBtn(
                          icon: Icons.refresh_rounded,
                          label: "Sıfırla",
                          color: Colors.redAccent,
                          onTap: _focusService.resetTimer),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- YARDIMCI METODLAR ---

  void _showDurationPicker() {
    Duration initialDuration = Duration(seconds: _focusService.totalTimeInSeconds);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.0))),
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Süre Seç", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Tamam", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: initialDuration,
                  onTimerDurationChanged: (Duration newDuration) {
                    if (newDuration.inSeconds > 0) {
                      _focusService.setDuration(newDuration.inMinutes);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  Widget _buildTimeChip(String label, int minutes) {
    bool isSelected = (_focusService.totalTimeInSeconds == minutes * 60);
    return ChoiceChip(
      label: Text("$label ($minutes dk)"),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) _focusService.setDuration(minutes);
      },
      selectedColor: const Color(0xFF1565C0).withOpacity(0.2),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon, 
    required String label, 
    required Color color, 
    required VoidCallback onTap
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 28),
      label: Text(label, style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
    );
  }
}