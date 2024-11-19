import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:satubc/main_screen.dart';
import 'auth_service.dart';
import 'landing_page.dart';
import 'login_page.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('id', '');
  Locale get currentLocale => _currentLocale;

  void setLocale(Locale locale) {
    if (!AppLocalizations.supportedLocales.contains(locale)) return;
    _currentLocale = locale;
    _saveLocale(locale);
    notifyListeners();
  }

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _currentLocale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> _saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final languageProvider = LanguageProvider();
  await languageProvider.loadSavedLocale();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'SatuBC',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          locale: languageProvider.currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('id', ''), // Indonesian
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const LandingPage(),
            '/login': (context) => const LoginPage(),
            '/main': (context) => const MainScreen(),
          },
        );
      },
    );
  }
}

class LanguageSelectionWidget extends StatelessWidget {
  const LanguageSelectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    return ListTile(
      title:
          Text(AppLocalizations.of(context)?.languageSelection ?? 'Language'),
      trailing: DropdownButton<Locale>(
        value: languageProvider.currentLocale,
        items: AppLocalizations.supportedLocales.map((Locale locale) {
          return DropdownMenuItem<Locale>(
            value: locale,
            child: Text(
                locale.languageCode == 'id' ? 'Bahasa Indonesia' : 'English'),
          );
        }).toList(),
        onChanged: (Locale? newLocale) {
          if (newLocale != null) {
            languageProvider.setLocale(newLocale);
          }
        },
      ),
    );
  }
}
