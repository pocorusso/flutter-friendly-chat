import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:math';
import 'dart:io';

void main() => runApp(new FriendlyChatApp());

class FriendlyChatApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'FriendlyChat',
      home: new ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  State createState() => new ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController textController = new TextEditingController();
  bool isComposing = false;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: new Text("FriendlyChat")),
      body: new Column(
        children: <Widget>[
          new Flexible(
            child: new FirebaseAnimatedList(
                query: reference,
                sort: (a, b) => b.key.compareTo(a.key),
                padding: new EdgeInsets.all(8.0),
                reverse: true,
                itemBuilder: (_, DataSnapshot snapshot, Animation<double> animation, x ) {
                  return new ChatMessage(snapshot: snapshot, animation: animation);
                }
            )
          ),
          new Divider(
            height: 1.0,
          ),
          new Container(
            decoration: new BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return new IconTheme(
        data: new IconThemeData(color: Theme.of(context).accentColor),
        child: new Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: new Row(
            children: <Widget>[
              new Container(
                margin: new EdgeInsets.symmetric(horizontal: 4.0),
                child: new IconButton(
                    icon: new Icon(Icons.photo_camera),
                    onPressed: () async {
                      await _ensureLoggedIn();
                      File imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);
                      int random = new Random().nextInt(100000);
                      StorageReference ref = FirebaseStorage.instance.ref().child("images/image_$random.jpg");
                      StorageUploadTask uploadTask = ref.put(imageFile);
                      StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
                      String downloadUrl = await storageTaskSnapshot.ref.getDownloadURL();
                      _sendMessage(imageUrl: downloadUrl);
                    },
                ),
              ),
              new Flexible(
                child: new TextField(
                  controller: textController,
                  onChanged: (String text) {
                    setState(() {
                      isComposing = text.length > 0;
                    });
                  },
                  onSubmitted: handleSubmitted,
                  decoration:
                      new InputDecoration.collapsed(hintText: "Send a message"),
                ),
              ),
              new Container(
                margin: new EdgeInsets.symmetric(horizontal: 4.0),
                child: new IconButton(
                  icon: new Icon(Icons.send),
                  onPressed: isComposing
                      ? () => handleSubmitted(textController.text)
                      : null,
                ),
              ),
            ],
          ),
        ));
  }

  void handleSubmitted(String text) async {
    textController.clear();
    setState(() {
      isComposing = false;
    });

    await _ensureLoggedIn();
    _sendMessage(text: text);
  }

  final reference = FirebaseDatabase.instance.reference().child("messages");

  void _sendMessage({String text, String imageUrl}){
    reference.push().set({
      'text': text,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl,
      'imageUrl': imageUrl,
    });
  }
}

class ChatMessage extends StatelessWidget {
  ChatMessage({this.snapshot, this.animation});

  final DataSnapshot snapshot;
  final Animation animation;

  @override
  Widget build(BuildContext context) {
    return new SizeTransition(
        sizeFactor: new CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        axisAlignment: 0.0,
        child: new Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0),
          child: new Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new Container(
                margin: const EdgeInsets.only(right: 16.0),
                child: new CircleAvatar(
                  backgroundImage:
                   new NetworkImage(snapshot.value['senderPhotoUrl']),
                ),
              ),
              new Expanded(
                child: new Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    new Text(
                        snapshot.value['senderName'],
                        style: Theme.of(context).textTheme.subhead
                    ),
                    new Container(
                      margin: const EdgeInsets.only(top: 5.0),
                      child: snapshot.value['imageUrl'] != null ?
                      new Image.network(
                        snapshot.value['imageUrl'],
                        width: 250.0,
                      ):
                      new Text(snapshot.value['text']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}

final googleSignIn = new GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null)
    user = await googleSignIn.signInSilently();
  if (user == null) {
    await googleSignIn.signIn();
  }
  if (await auth.currentUser() == null){
    GoogleSignInAuthentication userAuth =
        await googleSignIn.currentUser.authentication;
    AuthCredential credential = GoogleAuthProvider.getCredential(
        idToken: userAuth.idToken,
        accessToken: userAuth.accessToken
    );

    await auth.signInWithCredential(credential);
  }
}

