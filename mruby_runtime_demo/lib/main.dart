import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ruby_runtime/ruby_runtime.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await RubyRuntime.initialize();
  } catch (e) {
    // ignore: avoid_print
    print('Failed to initialize Ruby runtime: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruby Runtime Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Ruby Runtime Example'),
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
  final TextEditingController _controller = TextEditingController(
    text: '"Hello, Ruby!"\n5 + 3',
  );

  String _result = '';
  bool _isLoading = false;

  Future<void> _executeRuby() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final result = await RubyRuntime.eval(_controller.text);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _executeRubyFile() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final script = await rootBundle.loadString('assets/sample.rb');
      final dir = await getTemporaryDirectory();
      await dir.create(recursive: true);
      final file = File('${dir.path}/sample.rb');
      await file.writeAsString(script);

      final result = await RubyRuntime.runFile(file.path);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildExampleButton(String label, String code) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _controller.text = code;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      child: Text(label),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter Ruby code:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: TextField(
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'Enter Ruby code here...\\nExample:\\nputs "Hello, World!"\\n5 + 3',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                controller: _controller,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _executeRuby,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Execute Ruby Code'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _executeRubyFile,
                    child: const Text('Run sample.rb'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Result:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? '(No result yet)' : _result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Examples:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildExampleButton('Math', '1 + 2 * 3'),
                _buildExampleButton('String', '"Hello, " + "World!"'),
                _buildExampleButton(
                  'Array',
                  'numbers = [1, 2, 3]\nnumbers << 4\nnumbers.inspect',
                ),
                _buildExampleButton('Class', '''class Calc
  def add(a, b)
    a + b
  end
end
Calc.new.add(10, 20)'''),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
