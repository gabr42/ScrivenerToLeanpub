program scriv4lean;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  GpCommandLineParser in 'GpCommandLineParser.pas',
  Scrivener4Leanpub in 'Scrivener4Leanpub.pas',
  S4L.Anchors in 'S4L.Anchors.pas',
  S4L.BibTeX in 'S4L.BibTeX.pas',
  S4L.Captions in 'S4L.Captions.pas',
  S4L.Common in 'S4L.Common.pas',
  S4L.Context in 'S4L.Context.pas',
  S4L.Errors in 'S4L.Errors.pas',
  S4L.Format in 'S4L.Format.pas',
  S4L.Format.Markua in 'S4L.Format.Markua.pas',
  S4L.Global in 'S4L.Global.pas',
  S4L.Images in 'S4L.Images.pas',
  S4L.Macros in 'S4L.Macros.pas',
  S4L.Metadata in 'S4L.Metadata.pas',
  S4L.Notes in 'S4L.Notes.pas',
  S4L.Platform in 'S4L.Platform.pas',
  S4L.Processor in 'S4L.Processor.pas',
  S4L.Processor.State in 'S4L.Processor.State.pas',
  S4L.Processor.TableFormatter in 'S4L.Processor.TableFormatter.pas',
  S4L.Reader in 'S4L.Reader.pas',
  S4L.References in 'S4L.References.pas',
  S4L.TODOWriter in 'S4L.TODOWriter.pas',
  S4L.Writer in 'S4L.Writer.pas',
  S4L.Processor.Config in 'S4L.Processor.Config.pas',
  S4L.URLChecker in 'S4L.URLChecker.pas';

type
  TCommandLine = class
  strict private
    FBibTeXFile       : string;
    FCheckURLs        : boolean;
    FLeanpubFolder    : string;
    FNoCleanup        : boolean;
    FNumberCitations  : boolean;
    FScrivenerMMD     : string;
    FServerMode       : boolean;
    FWaitUntilModified: boolean;
  public
    [CLPPosition(1), CLPDescription('Scrivener MultiMarkdown file'), CLPRequired]
    property ScrivenerMMD: string read FScrivenerMMD write FScrivenerMMD;
    [CLPPosition(2), CLPDescription('Leanpub manuscript folder'), CLPRequired]
    property LeanpubFolder: string read FLeanpubFolder write FLeanpubFolder;
    [CLPPosition(3), CLPDescription('BibTeX bibliography file')]
    property BibTeXFile: string read FBibTeXFile write FBibTeXFile;
    [CLPName('c'), CLPLongName('checkurls', 'checku'), CLPDescription('Check if all URLs in the book are accessible')]
    property CheckURLs: boolean read FCheckURLs write FCheckURLs;
    [CLPName('n'), CLPLongName('nocleanup', 'noc'), CLPDescription('Disable markdown folder cleanup')]
    property NoCleanup: boolean read FNoCleanup write FNoCleanup;
    [CLPName('1'), CLPLongName('numbercitations', 'numbercit'), CLPDescription('Convert citation keys into numbers')]
    property NumberCitations: boolean read FNumberCitations write FNumberCitations;
    [CLPName('s'), CLPLongName('server', 'se'), CLPDescription('Enable server mode')]
    property ServerMode: boolean read FServerMode write FServerMode;
    [CLPName('w'), CLPLongName('wait', 'wa'), CLPDescription('Wait unit Scrivener file is modified')]
    property WaitUntilModified: boolean read FWaitUntilModified write FWaitUntilModified;
  end; { TCommandLine }

procedure Usage;
begin
  Writeln('scriv4lean v0.2.3');
  Writeln;
  Writeln('Usage:');
  for var s in CommandLineParser.Usage do
    Writeln(s);
end; { Usage }

function OptParam(paramNum: integer): string;
begin
  Result := '';
  if paramNum <= ParamCount then
    Result := ParamStr(paramNum);
end; { OptParam }

function MakeOptions(commandLine: TCommandLine): TConvertOptions;
begin
  Result := [];
  if commandLine.NoCleanup then
    Include(Result, TConvertOption.optNoCleanup);
  if commandLine.NumberCitations then
    Include(Result, TConvertOption.optNumberCitations);
  if commandLine.CheckURLs then
    Include(Result, TConvertOption.optCheckURLs);
end; { MakeOptions }

function ConvertOnce(commandLine: TCommandLine): boolean;
begin
  Result := true;
  var converter := CreateScrivener2Leanpub;
  var warnings: TArray<string>;
  if converter.Convert(commandLine.ScrivenerMMD, commandLine.LeanpubFolder,
       commandLine.BibTeXFile, MakeOptions(commandLine), warnings) then begin
    for var s in warnings do
      Writeln(s);
    Writeln('Converted')
  end
  else begin
    Writeln(converter.ErrorMsg);
    Result := false;
  end;
end; { ConvertOnce }

function RunInServerMode(commandLine: TCommandLine): boolean;
begin
  Writeln('Running in server mode, press Ctrl+C to stop ...');

  var lastFileTime: TDateTime := -1;
  var currFileTime: TDateTime;
  repeat
    try
      currFileTime := TFile.GetLastWriteTimeUtc(commandLine.ScrivenerMMD);
    except
      currFileTime := -2;
    end;

    if lastFileTime = -1 then
      lastFileTime := currFileTime;

    if (currFileTime = -2) or (currFileTime = lastFileTime) then
      Sleep(1000)
    else begin
      lastFileTime := currFileTime;
      Writeln;
      Writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Result := ConvertOnce(commandLine);
      if commandLine.WaitUntilModified then
        Exit;
    end;
  until false;
end; { RunInServerMode }

begin
  var exitCode := 0;
  try
    try
      var cmdLine := TCommandLine.Create;
      try
        if not CommandLineParser.Parse(cmdLine) then
          Usage
        else if cmdLine.ServerMode or cmdLine.WaitUntilModified then begin
          if not RunInServerMode(cmdLine) then
            exitCode := 1
        end
        else if not ConvertOnce(cmdLine) then
          exitCode := 1;
      finally FreeAndNil(cmdLine); end;
    except
      on E: Exception do begin
        Writeln(E.ClassName, ': ', E.Message);
        exitCode := 255;
      end;
    end;
  finally
    {$IFDEF MSWINDOWS}
    {$WARN SYMBOL_PLATFORM OFF}
    if DebugHook <> 0 then begin
      Write('> ');
      Readln;
    end;
    {$ENDIF}
    if exitCode <> 0 then
      Halt(exitCode);
  end;
end.
