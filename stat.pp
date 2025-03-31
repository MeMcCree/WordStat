{$mode objfpc}{$H+}

program stat;
type
	MapIdx = 0..65535;
	TTokenType = (TK_NAME, TK_TYPE, TK_NUM, TK_STR);
	TLexer = record
		data: PChar;
		dataLen: Integer;
		p: Integer;
	end;
const
	WhiteSpace: String = '0123456789`~!@#$%^&*-+_=\\|/''";:,.?<>(){}[]–„”';

function UTF8CodepointSize(ptr: PChar): Integer;
begin
	if Byte(ptr^) < Byte(128) then exit(1);
	if (Byte(ptr^) and Byte(%11100000)) = Byte(%11000000) then exit(2);
	if (Byte(ptr^) and Byte(%11110000)) = Byte(%11100000) then exit(3);
	if (Byte(ptr^) and Byte(%11111000)) = Byte(%11110000) then exit(4);
end;

function LexerNext(Var lexer: TLexer): String;
var
	codepoint: String;
	len: Integer;
begin
	if lexer.p >= lexer.dataLen then
	begin
		exit('');
	end;
	len := UTF8CodepointSize(lexer.data + lexer.p);
	SetLength(codepoint, len);
	Move((lexer.data + lexer.p)^, codepoint[1], len);
	result := codepoint;
	inc(lexer.p, len);
end;

function IsNameChar(c: String): Boolean;
begin
	if Length(c) = 0 then
	begin
		exit(false);
	end;
	result := (pos(c, WhiteSpace) = 0) and (Byte(c[1]) > Byte(32));
end;

function LowerChar(c: String): String;
begin
	if Length(c) = 0 then
	begin
		exit('');
	end;
	if Length(c) = 1 then
	begin
		case c[1] of
			'A'..'Z':
			begin
				c[1] := chr(ord(c[1]) + 32);
				result := c;
			end;
		else
			result := c;
		end;
	end
	else
	begin
		case c of
			'Ą': result := 'ą';
			'Ś': result := 'ś';
			'Ę': result := 'ę';
			'Ż': result := 'ż';
			'Ź': result := 'ź';
			'Ó': result := 'ó';
			'Ń': result := 'ń';
			'Ć': result := 'ć';
			'Ł': result := 'ł';
		else
			result := c;
		end;
	end;
end;

function IsNameBegChar(c: String): Boolean;
begin
	result := pos(c, WhiteSpace) = 0;
end;

const
	hp: uint64 = 277;

var
	hist: Array[MapIdx] of uint64;
	hashes: Array[MapIdx] of String;
	path: String;
	fin: File of Char;
	lexer: TLexer;
	codepoint: String;
	i, j: Integer;
	intChar: Integer;
	hash: uint64;
	word: String;
	c: Char;
begin
	if ParamCount < 1 then
	begin
		writeln('[ERROR] Expected filepath');
		ExitCode := 1;
		exit;
	end;

	for i := Low(MapIdx) to High(MapIdx) do
	begin
		hashes[i] := '';
		hist[i] := 0;
	end;

	path := paramStr(1);
	AssignFile(fin, path);
	try
		Reset(fin);
		lexer.dataLen := Filesize(fin);
		lexer.p := 0;

		lexer.data := Getmem(lexer.dataLen + 1);
		FillChar(lexer.data^, lexer.dataLen + 1, 0);
		BlockRead(fin, lexer.data^, lexer.dataLen);

		codepoint := LexerNext(lexer);
		while codepoint <> '' do
		begin
			while not IsNameChar(codepoint) and (codepoint <> '') do
			begin
				codepoint := LexerNext(lexer);
			end;

			if codepoint = '' then
				break;

			hash := 0;
			word := '';
			while IsNameChar(codepoint) and (codepoint <> '') do
			begin
				codepoint := LowerChar(codepoint);

				intChar := 0;
				for i := 1 to UTF8CodepointSize(@codepoint[1]) do
				begin
					intChar := intChar * 256 + Integer(codepoint[i]);
					word += codepoint[i];
				end;
				hash := hash * hp + intChar;
				codepoint := LexerNext(lexer);
			end;
			hash := hash mod uint64(High(MapIdx));
			hashes[hash] := word;
			hist[hash] := hist[hash] + 1;
		end;

		for i := Low(MapIdx) to High(MapIdx)-1 do
			for j := i + 1 to High(MapIdx) do
			begin
				if hist[i] < hist[j] then
				begin
					hash := hist[i];
					word := hashes[i];
					hist[i] := hist[j];
					hashes[i] := hashes[j];
					hist[j] := hash;
					hashes[j] := word;
				end;
			end;

		for i := Low(MapIdx) to High(MapIdx) do
		begin
			if hist[i] > 0 then
			begin
				write('"');
				for c in hashes[i] do
				begin
					write(c);
				end;
				write('" ', hist[i]);
				writeln();
			end;
		end;

		Freemem(lexer.data);
	finally
		CloseFile(fin);
	end;
end.