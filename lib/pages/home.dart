import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    //daftar data: judul + isi
    final List<Map<String, String>> items = [
      {
        "judul": "Prinsip Dasar",
        "isi": """
        Prinsip-prinsip dasar dalam menangani suatu keadaan darurta di antaranya adalah:
        1. Pastikan kita aman atau masih dalam bahaya (menjadi korban berikutnya).
        2. Menjauhkan korban dari sumber kecelakaan untuk mencegah berulang.
        3. Bila bekerja dalam tim, buatlah perencanaan yang matang dan dipahami.
        4. Jika banyak korban, utamakan korban yang paling parah.
        5. Buat catatan identitas, lokasi, waktu kejadian, dsb.
        6. Lakukan upaya penyelamatan lanjutan, hubungi tenaga medis bila perlu.
        """
      },
      {
        "judul": "CPR Resusitasi Jantung Paru",
        "isi": "Langkah-langkah melakukan CPR adalah ..."
      },
      {
        "judul": "Pendarahan dan Luka",
        "isi": "Cara menangani pendarahan dan luka ..."
      },
      {
        "judul": "Pernafasan",
        "isi": "Cara menangani gangguan pernafasan ..."
      },
      {
        "judul": "Masalah Jantung",
        "isi": "Cara menangani serangan jantung ..."
      },
      {
        "judul": "Stroke dan Sakit Kepala",
        "isi": "Langkah pertolongan pertama pada stroke dan sakit kepala ..."
      },
      {
        "judul": "Tulang dan Otot",
        "isi": "Cara menangani patah tulang atau cedera otot ..."
      },
      {
        "judul": "Keracunan dan Gigitan Hewan",
        "isi": "Langkah pertolongan pada keracunan dan gigitan hewan ..."
      },
      {
        "judul": "Kemasukan Benda Asing",
        "isi": "Cara menangani jika ada benda asing masuk ke tubuh ..."
      },
      {
        "judul": "Kecelakaan",
        "isi": "Langkah awal dalam kecelakaan ..."
      },
      {
        "judul": "Emergensi Lain",
        "isi": "Langkah pertolongan pada keadaan darurat lainnya ..."
      },
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // LOGO
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              
              const SizedBox(height: 15),

              // JUDUL
              const Text(
                "Langkah Awal P3K",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 30),

              // LIST EXPANSION
              Column(
                children: items.map((item){
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal:15, vertical: 5),
                      title: Text(
                        item["judul"]!,
                        style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                          item["isi"]!,
                          style:const TextStyle(
                            fontSize: 14,
                            height:1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
