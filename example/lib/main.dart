import 'package:easy_download_manager/easy_download_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  EasyDownloadManager downloadManager = EasyDownloadManager();

  List<Map<String, dynamic>> imagesUrl = [
    {'id':'1','url': 'https://img.freepik.com/free-vector/watercolor-holi-festival_23-2148829339.jpg'},
    {'id':'3','url': 'https://images.template.net/80274/Free-Rainbow-Color-Splash-Vector-1.jpg'},
    {'id':'4','url': 'https://img.freepik.com/free-vector/watercolor-holi-festival_23-2148829339.jpg'},
    {'id':'5','url': 'https://m.media-amazon.com/images/I/71RdU4jU3SL._AC_SX679_.jpg'},
  ];

  @override
  void initState() {
    super.initState();

    print('initState()...');
    downloadManager.initialize().then((value) {
      print('downloadManager.initialized');
      for (Map item in imagesUrl) {
        print('item ${item['id']} add');
        downloadManager
            .add(url: item['url'], extendedPath: 'images')
            .then((value) {
          item['item'] = value;
          print('item ${item['id']} updated. NULL = ${value?.file?.path}');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: imagesUrl.map((Map<String, dynamic> e) {
            return Expanded(
              child: ChangeNotifierProvider<DownloadItem?>.value(
                value: e['item'],
                child: Consumer<DownloadItem?>(builder: (context, downloadItem, _) {
                  if (downloadItem?.status == DownloadStatusType.downloaded &&
                      downloadItem?.file != null) {
                    return SizedBox(
                      width: double.infinity,
                      child: FlexImage(
                        imageFile: downloadItem!.file!,
                        boxFit: BoxFit.contain,
                      ),
                    );
                  }

                  return SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                        key: const Key('circular_loading_flex_future_image_level'),
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.blue.withOpacity(0.6))),
                  );
                }),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
