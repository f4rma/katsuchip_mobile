import 'package:flutter/material.dart';
import 'package:katsuchip_app/service/database.dart';
import 'package:katsuchip_app/theme.dart';

class EditPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const EditPage({super.key, required this.data});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late TextEditingController namaBarangField;
  late TextEditingController keteranganField;

  @override
  void initState() {
    super.initState();
    namaBarangField = TextEditingController(
      text: widget.data['namaBarang'] ?? '',
    );
    keteranganField = TextEditingController(
      text: widget.data['keterangan'] ?? '',
    );
  }

  @override
  void dispose() {
    namaBarangField.dispose();
    keteranganField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 60),
              Text(
                'Edit Data',
                style: large.copyWith(color: bg_red),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 10),
              Text(
                'Edit data perlengkapan sesuai kebutuhan.',
                textAlign: TextAlign.left,
                style: regular.copyWith(color: bg_black),
              ),
              const SizedBox(height: 30),
              Text(
                'Nama Barang',
                textAlign: TextAlign.left,
                style: medium.copyWith(color: bg_black),
              ),
              const SizedBox(height: 5),
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
              Text(
                'Keterangan Barang',
                textAlign: TextAlign.left,
                style: medium.copyWith(color: bg_black),
              ),
              const SizedBox(height: 5),
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
              Align(
                alignment: Alignment.center,
                child: Material(
                  color: bg_red,
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () async {
                      Map<String, dynamic> perlengkapanInfoMap = {
                        "namaBarang": namaBarangField.text.trim(),
                        "keterangan": keteranganField.text.trim(),
                      };

                      try {
                        await DatabaseMethod().updatePerlengkapan(
                            perlengkapanInfoMap,
                            widget.data['id'], // gunakan id dari data
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data berhasil diupdate'),
                          ),
                        );
                        Navigator.pop(context); // kembali ke halaman sebelumnya
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal update: $e')),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 100,
                        right: 100,
                        top: 15,
                        bottom: 15,
                      ),
                      child: Text(
                        "Update",
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