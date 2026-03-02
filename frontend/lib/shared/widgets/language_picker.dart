import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/cubit/locale_cubit.dart';

class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final current = _languages.firstWhere(
          (l) => l.code == locale.languageCode,
          orElse: () => _languages.first,
        );
        return ListTile(
          leading: Icon(Icons.language, color: Colors.green.shade700),
          title: const Text('Language', style: TextStyle(fontSize: 12, color: Colors.grey)),
          subtitle: Text(
            '${current.flag}  ${current.nativeName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguagePicker(context),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final cubit = context.read<LocaleCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _LanguagePickerSheet(),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Language / भाषा चुनें',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _languages.length,
                  itemBuilder: (context, i) {
                    final lang = _languages[i];
                    final isSelected = locale.languageCode == lang.code;
                    return ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(lang.flag, style: const TextStyle(fontSize: 22)),
                      ),
                      title: Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.green.shade800 : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        lang.englishName,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Colors.green.shade700)
                          : null,
                      onTap: () {
                        context.read<LocaleCubit>().setLocale(Locale(lang.code));
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Language {
  final String code;
  final String nativeName;
  final String englishName;
  final String flag;
  const _Language(this.code, this.nativeName, this.englishName, this.flag);
}

const _languages = [
  _Language('en', 'English', 'English', '🇬🇧'),
  _Language('hi', 'हिंदी', 'Hindi', '🇮🇳'),
  _Language('or', 'ଓଡ଼ିଆ', 'Odia', '🇮🇳'),
  _Language('te', 'తెలుగు', 'Telugu', '🇮🇳'),
  _Language('ta', 'தமிழ்', 'Tamil', '🇮🇳'),
  _Language('mr', 'मराठी', 'Marathi', '🇮🇳'),
  _Language('bn', 'বাংলা', 'Bengali', '🇮🇳'),
  _Language('gu', 'ગુજરાતી', 'Gujarati', '🇮🇳'),
  _Language('kn', 'ಕನ್ನಡ', 'Kannada', '🇮🇳'),
  _Language('ml', 'മലയാളം', 'Malayalam', '🇮🇳'),
  _Language('pa', 'ਪੰਜਾਬੀ', 'Punjabi', '🇮🇳'),
];
