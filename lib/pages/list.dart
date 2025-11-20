import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:katsuchip_app/service/database.dart';
import 'package:katsuchip_app/theme.dart';
import 'package:katsuchip_app/pages/edit.dart';

class List_Data extends StatefulWidget {
  const List_Data({super.key});

  @override
  State<List_Data> createState() => _List_DataState();
}

class _List_DataState extends State<List_Data> {
  List<Map<String, dynamic>> perlengkapanList = [];
  bool _isInit = true;
  bool _isLoading = false;
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if(_isInit){
      setState((){
        _isLoading = true;
      });
      try {
        perlengkapanList = await DatabaseMethod().getPerlengkapanList();
      }catch(e){
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching data: $e')));
      }
      setState((){
        _isLoading = false;
      });
      _isInit = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: _isLoading
        ? const Center(child: CircularProgressIndicator())
        :
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Text('List Perlengkapan ', style: large.copyWith(color: bg_red)),
            const SizedBox(height:10),
            Text(
              'Daftar perlengkapan kebutuhan PMR periode 2025/2026',
              style: regular.copyWith(color: bg_black),
            ),
            const SizedBox(height: 30),
            Expanded(
              // agar ListView bisa ambil sisa layar
              child: ListView.builder(
                itemCount: perlengkapanList.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              perlengkapanList[index]['namaBarang'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(perlengkapanList[index]['keterangan']), 
                          ],
                        ),                                                                                                            
                        const Spacer(),
                        IconButton(
                          onPressed: () async {
                            // Hapus data dari Firestore
                            await DatabaseMethod().deletePerlengkapan(
                              perlengkapanList[index]['id']
                            );
                            // Hapus data dari list lokal
                            setState(() {
                              perlengkapanList.removeAt(index);
                            });
                          },
                          icon: const FaIcon(
                            FontAwesomeIcons.trash,
                            color: Color(0xffF25C24),
                            size: 20,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditPage(
                                  data: perlengkapanList[index],
                                ),
                              ),
                            ).then((_) async{
                              // Refresh data setelah kembali dari halaman EditPage
                              setState(() {
                                _isInit = true; //reset to fetch data again
                              });
                              try {
                                perlengkapanList = await DatabaseMethod().getPerlengkapanList();
                              } catch (e) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text('Error fetching data: $e')
                                  )
                                );
                              }
                              setState(() {
                                _isLoading = false;
                              });
                            });
                          },
                          icon: const FaIcon(
                            FontAwesomeIcons.penToSquare,
                            color: Color(0xff106779),
                            size: 20,
                          )
                        )
                      ],
                    ),
                  );
                },
              )
            )
          ]
        )
      )
    );
  }
}
