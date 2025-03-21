import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI News Summarizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 2,
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<dynamic> _newsArticles = [];
  bool _isLoading = false;

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _newsArticles = [];
    });

    try {
      final newsApiKey = dotenv.env['NEWS_API_KEY'];
      final response = await http.get(Uri.parse(
        'https://newsapi.org/v2/top-headlines?country=us&pageSize=6&apiKey=$newsApiKey',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _newsArticles = data['articles'];
          _isLoading = false;
        });
      } else {
        print('Failed to load news: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load news.'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching news: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred.'),
          ),
        );
      }
    }
  }

  Future<String> _summarizeArticle(String articleText) async {
    try {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: geminiApiKey!,
      );
      final prompt =
          'Summarize the following news article in a few sentences:\n\n$articleText';

      final content = [Content.text(prompt)];
      final result = await model.generateContent(content);
      return result.text ?? 'Summary not available.';
    } catch (e) {
      print('Error summarizing article: $e');
      return 'Summary not available.';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI News Summarizer'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView.builder(
              itemCount: _newsArticles.length,
              itemBuilder: (context, index) {
                final article = _newsArticles[index];
                return FadeInUp( // Apply FadeInUp animation
                  delay: Duration(milliseconds: 100 * index), // Stagger animations
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: InkWell(
                      onTap: () async {
                        if (article['url'] != null) {
                          final Uri url = Uri.parse(article['url']);
                          if (!await launchUrl(url)) {
                            throw Exception('Could not launch $url');
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article['title'] ?? 'No Title',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<String>(
                              future: _summarizeArticle(article['description'] ??
                                  article['content'] ??
                                  'No Description Available'),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text('Summarizing...');
                                } else if (snapshot.hasError) {
                                  return const Text('Summary failed.');
                                } else {
                                  return Text(snapshot.data ??
                                      'Summary not available.');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchNews,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
