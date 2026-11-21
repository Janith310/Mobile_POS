import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/login_screen.dart';

void main(){
  group('LoginScreen Widget Tests', (){
    testWidgets('Renders title, emails and password field, and Sign In button',
        (WidgetTester tester) async{
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      
        })
  })
}