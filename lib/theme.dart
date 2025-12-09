import 'package:flutter/material.dart';

// tambahkan kode hex di belakang huruf 0xff
// COLOR
Color white = const Color(0xffFFFFFF);
Color bg_black = const Color(0xff202020);
Color bg_red = Color (0xffEB4040);
Color bg_grey = Color(0xff6B6B6B);
// warna latar global app
Color bg_surface = const Color(0xFFFFF4DE);

//Gunakan text large untuk dimodified sesuai kebutuhan
//ukuran dan style font disesuaikan dengan rancangan UI di figma
// khusus untuk fontWeight dapat dilihat stylenya pada web google font poppins

// FONT
TextStyle large = const TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w800,
  fontFamily: 'Poppins',
);
TextStyle regular = large.copyWith(fontSize: 11, fontWeight: FontWeight.normal);
TextStyle medium = large.copyWith(fontSize: 11, fontWeight: FontWeight.w600);


