import 'package:flutter/material.dart';
import 'package:katsuchip_app/service/database.dart';
import 'package:katsuchip_app/theme.dart';

class Add_Data extends StatefulWidget {
  const Add_Data({super.key});
  @override
  State<Add_Data> createState() => _Add_DataState();
}

class _Add_DataState extends State<Add_Data> {
  final namaBarangField = TextEditingController();
  final keteranganField = TextEditingController();

  @override
  void dispose() {
    namaBarangField.dispose();
    keteranganField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal:20),
            children: [
              const SizedBox(height: 60),
              //JUDUL
              Text(
                'Tambah Data',
                style: large.copyWith(color: bg_red),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 10),
              Text(
                'Isikan data perlengkapan sesuai\nketentuan..',
                textAlign: TextAlign.left,
                style: regular.copyWith(color: bg_black),
              ),
              const SizedBox(height: 30),

              // NAMA BARANG
              Text(
                'Nama Barang',
                textAlign: TextAlign.left,
                style: medium.copyWith(color: bg_black),
              ),
              const SizedBox(height: 5),

              // TEXT FIELD NAMA BARANG
              TextFormField(
                controller: namaBarangField,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14.0,
                    horizontal: 12.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: BorderSide(color: bg_grey),
                  ),
                  label: Text(
                      "isikan nama barang ",
                      style: regular.copyWith(color: bg_grey),
                    ),
                  ),
                  ),
                  const SizedBox(height: 20),
                  // KETERANGAN BARANG
                  Text(
                    'Keterangan Barang',
                    textAlign: TextAlign.left,
                    style: medium.copyWith(color: bg_black),
                  ),
                  const SizedBox(height: 5),
                  // TEXT FIELD KETERANGAN BARANG
                  TextFormField(
                    controller: keteranganField,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14.0,
                        horizontal: 12.0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                        borderSide: BorderSide(color: bg_grey),
                      ),
                      label: Text(
                        "isikan keterangan barang ",
                        style: regular.copyWith(color: bg_grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  // BUTTON
                  Align(
                    alignment: Alignment.center,
                    child: Material(
                      color: bg_red,
                      borderRadius: BorderRadius.circular(25),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () async {
                          // Map data
                          Map<String, dynamic> perlengkapanInfoMap = {
                            "namaBarang": namaBarangField.text.trim(),
                            "keterangan": keteranganField.text.trim(),
                          };

                          // Buat id unik (jika belum ada variabel Id)
                          String id =
                              DateTime.now().millisecondsSinceEpoch.toString();

                          try {
                            // Panggil method simpan ke Firestore
                            await DatabaseMethod().addPerlengkapan(
                                perlengkapanInfoMap,
                                id,
                            );

                            // Tampilkan notifikasi sukses
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Data berhasil disimpan'),
                              ),
                            );

                            // Kosongkan fieldS
                            namaBarangField.clear();
                            keteranganField.clear();
                          } catch (e) {
                            // Jika gagal
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal menyimpan: $e')),
                            );
                          }
                        },
                        // mengatur ukuran button
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 120,
                            right: 120,
                            top: 15,
                            bottom: 15,
                          ),
                          child: Text(
                            "Kirim",
                            style: medium.copyWith(color: white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
