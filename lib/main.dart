// main.dart
// ignore_for_file: avoid_print

import 'package:checkdeeplink/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:share/share.dart';
// import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // Check if you received the link via `getInitialLink` first
  // final PendingDynamicLinkData? initialLink =
  //     await FirebaseDynamicLinks.instance.getInitialLink();

  // if (initialLink != null) {
  //   final Uri deepLink = initialLink.link;
  //   handleDeepLink(deepLink);
  // }

  // FirebaseDynamicLinks.instance.onLink.listen(handleDynamicLink);

  runApp(MyApp());
}

// void handleDynamicLink(PendingDynamicLinkData? dynamicLink) {
//   if (dynamicLink != null) {
//     final Uri deepLink = dynamicLink.link;
//     print('Dynamic link received: $deepLink');
//     handleDeepLink(deepLink);
//   }
// }

// void handleDeepLink(Uri deepLink) {
//   final String? imageUrl = deepLink.queryParameters['imageUrl'];
//   if (imageUrl != null) {
//     Navigator.of(globalContext!).push(MaterialPageRoute(
//       builder: (context) => DetailPage(imageUrl: imageUrl),
//     ));
//   }
// }

BuildContext? globalContext;

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    globalContext = context;
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final Map<String, dynamic> args =
              settings.arguments as Map<String, dynamic>;
          final String imageUrl = args['imageUrl'] as String;
          return MaterialPageRoute(
            builder: (_) => DetailPage(imageUrl: imageUrl),
          );
        } else {
          return MaterialPageRoute(builder: (_) => const HomePage());
        }
      },
      title: 'Share Image',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FirebaseStorage storage = FirebaseStorage.instance;
  late List<Map<String, dynamic>> images;

  Future<String> _createDynamicLink(String imageUrl) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://firebasedisplay.page.link',
      link: Uri.parse('https://nguyentien2202.github.io/image/$imageUrl'),
      androidParameters: const AndroidParameters(
        packageName: 'com.example.checkdeeplink',
      ),
    );

    final ShortDynamicLink shortLink =
        await FirebaseDynamicLinks.instance.buildShortLink(parameters);
    return shortLink.shortUrl.toString();
  }

  @override
  void initState() {
    super.initState();
    loadImages();
  }

  Future<void> loadImages() async {
    try {
      final List<Map<String, dynamic>> loadedImages = await _loadImages();
      setState(() {
        images = loadedImages;
      });
    } catch (error) {
      print("Error loading images: $error");
    }
  }

  Future<void> _upload(String inputSource) async {
    final picker = ImagePicker();
    XFile? pickedImage;
    try {
      pickedImage = await picker.pickImage(
          source: inputSource == 'camera'
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 1920);

      final String fileName = path.basename(pickedImage!.path);
      File imageFile = File(pickedImage.path);

      try {
        await storage.ref(fileName).putFile(imageFile);
        setState(() {});
      } on FirebaseException catch (error) {
        if (kDebugMode) {
          print(error);
        }
      }
    } catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadImages() async {
    List<Map<String, dynamic>> files = [];

    final ListResult result = await storage.ref().list();
    final List<Reference> allFiles = result.items;

    await Future.forEach<Reference>(allFiles, (file) async {
      final String fileUrl = await file.getDownloadURL();
      files.add({
        "url": fileUrl,
        "path": file.fullPath,
      });
    });

    files.sort((a, b) {
      return a["path"].compareTo(b["path"]);
    });

    return files;
  }

  Future<void> _delete(String ref) async {
    await storage.ref(ref).delete();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Image'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _upload('camera'),
                  icon: const Icon(Icons.camera),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _upload('gallery'),
                  icon: const Icon(Icons.library_add),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const Gap(20),
            Expanded(
              child: FutureBuilder(
                future: _loadImages(),
                builder: (context,
                    AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    List<Map<String, dynamic>> images = snapshot.data ?? [];

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> image = images[index];

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 5.0,
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              InkWell(
                                onTap: () {
                                  _showImageDialog(image['url']);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.network(
                                    image['url'],
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                child: InkWell(
                                  onTap: () => _delete(image['path']),
                                  child: Container(
                                    width: 35.0,
                                    height: 35.0,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.green,
                                      size: 25,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(String imageUrl) async {
    String dynamicLink = await _createDynamicLink(imageUrl);

    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Image.network(imageUrl),
          actions: [
            ElevatedButton(
              onPressed: () {
                print('Share link: $dynamicLink');
                _shareDynamicLink(dynamicLink);
                Navigator.pop(context);
              },
              child: const Text('Share Link'),
            ),
          ],
        );
      },
    );
  }

  void _shareDynamicLink(String dynamicLink) {
    Share.share('Check out this image: $dynamicLink');
  }
}

class DetailPage extends StatelessWidget {
  final String imageUrl;

  const DetailPage({required this.imageUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Detail'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(imageUrl),
          ],
        ),
      ),
    );
  }
}
