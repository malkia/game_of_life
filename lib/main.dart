import 'package:flutter/material.dart';
import 'game_of_life.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Game of Life',
      theme: ThemeData(primarySwatch: Colors.amber),
      home: MyHomePage());
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Game Of Life')),
      body: Center(child: GameOfLifeWidget(width: 512, height: 512)));
}
