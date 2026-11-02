import 'dart:io' hide HttpClient, Socket;

import '../ports/file_sync_port.dart';

// HttpClient chỉ xuất hiện trong comment.
/* Socket trong block comment /* lồng nhau RawSocket */ vẫn là comment */
const url = 'http://example.invalid'; // '//' trong chuỗi không mở comment
const label = 'Socket và WebSocket trong chuỗi không bị tính';
const raw = r'C:\HttpClient\';
File? target;
