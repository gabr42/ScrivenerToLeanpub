unit Scrivener4Leanpub;

interface

uses
  S4L.Errors, S4L.Format;

type
  TConvertOption = (optNoCleanup, optNumberCitations);
  TConvertOptions = set of TConvertOption;

  IScrivener4Leanpub = interface(IErrorBase)
  ['{B5F8B025-69D6-40FD-BAC2-8296EAB20B52}']
    function Convert(
      const scrivenerMarkdownFile, leanpubManuscriptFolder, bibTeXFile: string;
      options: TConvertOptions; var warnings: TArray<string>): boolean;
  end; { IScrivener4Leanpub }

function CreateScrivener2Leanpub: IScrivener4Leanpub;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils,
  S4L.Common, S4L.Reader, S4L.Writer, S4L.TODOWriter, S4L.Global, S4L.Processor,
  S4L.Anchors, S4L.Context, S4L.References, S4L.Images, S4L.Captions,
  S4L.Macros, S4L.Format.Markua, S4L.BibTeX, S4L.Notes,
  S4L.Processor.Config;

type
  TScrivener4Leanpub = class(TErrorBase, IScrivener4Leanpub)
  strict protected
    function  CreateFolder(const folderName: string): boolean;
    procedure DeleteResources(const folder, markdownFile: string);
    function  MapOptions(options: TConvertOptions): TProcessorOptions;
  public
    function  Convert(
      const scrivenerMarkdownFile, leanpubManuscriptFolder, bibTeXFile: string;
      options: TConvertOptions; var warnings: TArray<string>): boolean;
  end; { TScrivener4Leanpub }

{ exports }

function CreateScrivener2Leanpub: IScrivener4Leanpub;
begin
  Result := TScrivener4Leanpub.Create;
end; { CreateScrivener2Leanpub }

function TScrivener4Leanpub.Convert(
  const scrivenerMarkdownFile, leanpubManuscriptFolder, bibTeXFile: string;
  options: TConvertOptions; var warnings: TArray<string>): boolean;
var
  bookWriter: IWriter;
  content: string;
  errMsg: string;
begin
  if scrivenerMarkdownFile = '' then
    Exit(SetError('Scrivener markdown file not specified'));
  if not TFile.Exists(scrivenerMarkdownFile) then
    Exit(SetError('Scrivener markdown file %s does not exist', [scrivenerMarkdownFile]));
  if leanpubManuscriptFolder = '' then
    Exit(SetError('Leanpub manuscript folder not specified'));
  if not TDirectory.Exists(leanpubManuscriptFolder) then
    Exit(SetError('Leanpub manuscript folder %s does not exist', [leanpubManuscriptFolder]));

  var global := CreateGlobal;
  global.LeanpubManuscriptFolder := IncludeTrailingPathDelimiter(leanpubManuscriptFolder);

  var format := CreateMarkuaFormat;
  if not Asgn(Result, CreateFolder(global.LeanpubManuscriptFolder + format.GetImagesFolder)) then
    Exit;

  global.ScrivenerFolder := IncludeTrailingPathDelimiter(ExtractFilePath(scrivenerMarkdownFile));
  global.ScrivenerReader := CreateReader(scrivenerMarkdownFile, errMsg, 60, 500);
  if not assigned(global.ScrivenerReader) then
    Exit(SetError(errMsg));

  content := ChangeFileExt(ExtractFileName(scrivenerMarkdownFile), '.txt');
  if content = format.GetBookFileName then
    content := ChangeFileExt(content, '1.txt');
  global.ContentWriter := CreateWriter(global.LeanpubManuscriptFolder + content, errMsg);
  if not assigned(global.ContentWriter) then
    Exit(SetError(errMsg));

  if bibTeXFile <> '' then begin
    global.BibTeX := CreateBibTex(format);
    if not global.BibTeX.Read(bibTeXFile) then
      Exit(SetError('[BibTeX] ' + global.BibTeX.ErrorMsg));
  end;

  bookWriter := CreateWriter(global.LeanpubManuscriptFolder + format.GetBookFileName, errMsg);
  if not assigned(bookWriter) then
    Exit(SetError(errMsg));
  bookWriter.WriteLine(content);

  var todoWriter := CreateTODOWriter(global.LeanpubManuscriptFolder + '_todo.txt');
  var processor := CreateProcessor(global, CreateAnchors, CreateContext, CreateReferences,
                                   todoWriter, CreateImages, CreateCaptions,
                                   CreateMacros(global), format,
                                   CreateNotes(format));
  if not processor.Run(MapOptions(options)) then
    Exit(SetError(processor.ErrorMsg));

  if not (optNoCleanup in options) then
    DeleteResources(global.ScrivenerFolder, scrivenerMarkdownFile);

  global.ContentWriter.Flush;
  global.ContentWriter := nil;
  global.ScrivenerReader := nil;
  global := nil;

  warnings := processor.Warnings;

  Result := true;
end; { TScrivener4Leanpub.Convert }

function TScrivener4Leanpub.CreateFolder(const folderName: string): boolean;
begin
  Result := TDirectory.Exists(folderName);
  if not Result then begin
    try
      TDirectory.CreateDirectory(folderName);
      Result := TDirectory.Exists(folderName);
      if not Result then
        SetError('Failed to create folder %s', [folderName]);
    except
      on E: Exception do
        Result := SetError('Failed to create folder %s: %s', [folderName, E.Message]);
    end;
  end;
end; { TScrivener4Leanpub.CreateFolder }

procedure TScrivener4Leanpub.DeleteResources(const folder, markdownFile: string);
var
  SR        : TSearchRec;
  targetName: string;
begin
  if FindFirst(folder + '*.*', 0, SR) = 0 then try
    repeat
      var fullName := folder + SR.Name;
      if (not TDirectory.Exists(fullName))
         and (not FileGetSymLinkTarget(fullName, targetName))
         and (not SameText(fullName, markdownFile))
      then
        DeleteFile(fullName);
    until FindNext(SR) <> 0;
  finally FindClose(SR); end;
end; { TScrivener4Leanpub.DeleteResources }

function TScrivener4Leanpub.MapOptions(options: TConvertOptions): TProcessorOptions;
begin
  Result := [];
  if TConvertOption.optNumberCitations in options then
    Include(Result, TProcessorOption.optNumberCitations);
end; { TScrivener4Leanpub.MapOptions }

end.
