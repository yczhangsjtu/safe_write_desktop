import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'storage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Writing',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Main(title: 'Safe Writing'),
    );
  }
}

class Main extends StatefulWidget {
  Main({Key? key, this.title}) : super(key: key);
  final String? title;

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  FileNameContent? _content;
  Plaintext? _plaintext;
  TextEditingController? _passwordController;
  TextEditingController? _editTitleController;
  TextEditingController? _editorController;
  FocusNode? _editTitleFocusNode;
  ScrollController? _editingAreaScrollController;
  ScrollController? _leftsideScrollController;
  String? _password;
  int selected = 0;
  bool _editTitle = false;
  String? _errorText;
  final _defaultFontSize = 18;

  bool _enableOutsideEditingAreaScroll = true;
  bool _enableEditingAreaScroll = true;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _editTitleController = TextEditingController();
    _editorController = TextEditingController();
    _editTitleFocusNode = FocusNode();
    _editTitleFocusNode?.addListener(() {
      if (!(_editTitleFocusNode?.hasFocus ?? false)) {
        _completeEditTitle(_editTitleController?.text ?? "");
      }
    });
    _editingAreaScrollController = ScrollController();
    _leftsideScrollController = ScrollController();
    _passwordController?.addListener(() {
      _errorText = null;
      setState(() {});
    });
    _editorController?.addListener(() {
      _plaintext?.passages[selected].content = _editorController?.text ?? "";
    });
  }

  @override
  void dispose() {
    _passwordController?.dispose();
    _editTitleController?.dispose();
    _editorController?.dispose();
    _editTitleFocusNode?.dispose();
    _editingAreaScrollController?.dispose();
    _leftsideScrollController?.dispose();
    super.dispose();
  }

  Widget _buildLockScreen() {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock),
      TextButton(
        child: Text(_content?.path ?? "No File Selected"),
        onPressed: () async {
          _content = await readCiphertext();
          setState(() {});
        },
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 300,
            child: TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: "Password",
                isCollapsed: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
                errorText: _errorText,
              ),
              obscureText: true,
            ),
          ),
          OutlinedButton(
              child: Text("Open"),
              onPressed: (_passwordController?.text.isEmpty ?? true) ||
                      (_content == null)
                  ? null
                  : () async {
                      _password = _passwordController?.text;
                      _plaintext =
                          await fromCiphertext(_content?.content, _password);
                      if (_plaintext == null) {
                        setState(() {
                          _errorText = "Wrong password";
                        });
                        return;
                      }
                      selected = 0;
                      _editorController?.text =
                          _plaintext?.passages[selected].content ?? "";
                      _passwordController?.text = "";
                      setState(() {});
                    }),
          OutlinedButton(
              child: Text("New"),
              onPressed: _passwordController?.text.isEmpty ?? true
                  ? null
                  : () async {
                      _password = _passwordController?.text;
                      if (_password == null || _password!.isEmpty) {
                        return;
                      }
                      _plaintext = Plaintext([
                        Passage("Untitled", ""),
                      ]);
                      _content = FileNameContent(
                          "", await _plaintext!.encrypt(_password!) ?? "");
                      selected = 0;
                      _editorController?.text =
                          _plaintext?.passages[selected].content ?? "";
                      _passwordController?.text = "";
                      setState(() {});
                    }),
        ],
      ),
      Container(height: MediaQuery.of(context).size.height / 6)
    ]));
  }

  Widget _buildEditScreen() {
    return Row(
        children: [_buildLeftSide(), Expanded(child: _buildEditingArea())]);
  }

  Widget _buildLeftSide() {
    return Container(
        width: MediaQuery.of(context).size.width / 6,
        height: MediaQuery.of(context).size.height,
        color: Colors.lightBlue[100],
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _leftsideScrollController,
                child: ListView.builder(
                    controller: _leftsideScrollController,
                    itemCount: _plaintext?.passages.length,
                    itemBuilder: _listItemBuilder),
              ),
            ),
            Wrap(
              children: [
                TextButton(
                    child: Text("Add"),
                    onPressed: () {
                      _plaintext?.passages.add(Passage("Untitled", ""));
                      selected = (_plaintext?.passages.length ?? 1) - 1;
                      setState(() {});
                    }),
                TextButton(
                    child: Text("Del"),
                    onPressed: () {
                      _plaintext?.passages.removeAt(selected);
                      if (_plaintext?.passages.isEmpty ?? true) {
                        _plaintext?.passages = [Passage("Untitled", "")];
                      }
                      if (selected >= (_plaintext?.passages.length ?? 0)) {
                        selected = (_plaintext?.passages.length ?? 1) - 1;
                      }
                      onSelect(selected);
                    }),
                TextButton(
                  child: Text("Help"),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text("Help"),
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Save: Cmd + S"),
                                  Text("Lock: Cmd + L"),
                                  Text("Bigger: Cmd + Up"),
                                  Text("Smaller: Cmd + Down"),
                                ]),
                          );
                        });
                  },
                )
              ],
            )
          ],
        ));
  }

  Widget _listItemBuilder(BuildContext context, int index) {
    return GestureDetector(
      onTap: () {
        if (_editTitle) {
          _completeEditTitle(_editTitleController?.text ?? "Untitled");
        }
        onSelect(index);
      },
      onDoubleTap: () {
        if (_editTitle) {
          _completeEditTitle(_editTitleController?.text ?? "Untitled");
        }
        onSelect(index);
        _editTitle = true;
        _editTitleFocusNode?.requestFocus();
        _editTitleController?.text = _plaintext?.passages[selected].title ?? "";
      },
      child: Container(
          padding: EdgeInsets.all(4.0),
          color: selected == index ? Colors.lightBlue[200] : Colors.transparent,
          child: _editTitle && selected == index
              ? TextField(
                  focusNode: _editTitleFocusNode,
                  onSubmitted: (value) {
                    _completeEditTitle(value);
                  },
                  scrollPhysics: NeverScrollableScrollPhysics(),
                  controller: _editTitleController,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.all(4.0),
                    border: OutlineInputBorder(),
                  ),
                )
              : Text(_plaintext?.passages[index].title ?? "")),
    );
  }

  Widget _buildEditingArea() {
    // This part is problematic at the current version of Flutter (2.0.6)
    // which does not handle the dragging very well
    // Hard to select text
    return FocusableActionDetector(
      shortcuts: {
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyS,
        ): SaveIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyL,
        ): LockIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.arrowUp,
        ): IncreaseSizeIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.arrowDown,
        ): DecreaseSizeIntent()
      },
      actions: {
        SaveIntent: CallbackAction(onInvoke: (e) async {
          _content?.content = await _plaintext!.encrypt(_password!) ?? "";
          _content?.save();
        }),
        LockIntent: CallbackAction(onInvoke: (e) async {
          _content?.content = await _plaintext!.encrypt(_password!) ?? "";
          if (_content != null && _content!.path.isEmpty) {
            _content!.path = "New File";
          }
          _plaintext = null;
          _editorController?.text = "";
          setState(() {});
        }),
        IncreaseSizeIntent: CallbackAction(onInvoke: (e) async {
          _plaintext?.fontSize = min(_plaintext!.fontSize + 1, 60);
          setState(() {});
        }),
        DecreaseSizeIntent: CallbackAction(onInvoke: (e) async {
          _plaintext?.fontSize = max(_plaintext!.fontSize - 1, 12);
          setState(() {});
        }),
      },
      child: Container(
        height: MediaQuery.of(context).size.height,
        child: Scrollbar(
          controller: _editingAreaScrollController,
          child: TextField(
              scrollPhysics: ClampingScrollPhysics(),
              controller: _editorController,
              expands: false,
              scrollController: _editingAreaScrollController,
              maxLines: null,
              style: TextStyle(
                  fontSize:
                      (_plaintext?.fontSize ?? _defaultFontSize).toDouble()),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.0),
              )),
        ),
      ),
    );
  }

  void onSelect(int index) {
    setState(() {
      selected = index;
      _editorController?.text = _plaintext?.passages[index].content ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: _plaintext == null ? _buildLockScreen() : _buildEditScreen(),
    );
  }

  void _completeEditTitle(String value) {
    if (value.isEmpty) {
      value = "Untitled";
    }
    _plaintext?.passages[selected].title = value;
    _editTitle = false;
    setState(() {});
  }
}

class SaveIntent extends Intent {}

class LockIntent extends Intent {}

class IncreaseSizeIntent extends Intent {}

class DecreaseSizeIntent extends Intent {}
