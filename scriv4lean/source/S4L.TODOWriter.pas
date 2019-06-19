unit S4L.TODOWriter;

interface

uses
  S4L.Errors;

type
  ITODOWriter = interface(IErrorBase) ['{46BEC6AE-1C9B-4C42-9CA9-80940B012A36}']
    function  Add(const path, todo: string): boolean;
    function  All: TArray<string>;
    procedure Flush;
  end; { ITODOWriter }

function CreateTODOWriter(const fileName: string): ITODOWriter;

implementation

uses
  System.SysUtils, System.Classes,
  S4L.Writer;

type
  TTODOWriter = class(TErrorBase, ITODOWriter)
  strict private
    FCurrentPath: string;
    FFileName   : string;
    FTODOs      : TStringList;
    FTODOWriter : IWriter;
  public
    constructor Create(const fileName: string);
    destructor  Destroy; override;
    function  Add(const path, todo: string): boolean;
    function  All: TArray<string>;
    procedure Flush;
  end; { TTODOWriter }

{ exports }

function CreateTODOWriter(const fileName: string): ITODOWriter;
begin
  Result := TTODOWriter.Create(fileName);
end; { CreateTODOWriter }

{ TTODOWriter }

constructor TTODOWriter.Create(const fileName: string);
begin
  inherited Create;
  FFileName := fileName;
  FTODOs := TStringList.Create;
end; { TTODOWriter.Create }

destructor TTODOWriter.Destroy;
begin
  FreeAndNil(FTODOs);
  inherited;
end; { TTODOWriter.Destroy }

function TTODOWriter.Add(const path, todo: string): boolean;
var
  errMsg: string;
begin
  if not assigned(FTODOWriter) then begin
    FTODOWriter := CreateWriter(FFileName, errMsg);
    if not assigned(FTODOWriter) then
      Exit(SetError(errMsg));
  end;

  if path <> FCurrentPath then begin
    if FCurrentPath <> '' then
      FTODOs.Add('');
    FTODOs.Add(path);
    FCurrentPath := path;
  end;
  FTODOs.Add(todo);

  Result := true;
end; { TTODOWriter.Add }

function TTODOWriter.All: TArray<string>;
begin
  Result := FTODOs.ToStringArray;
end; { TTODOWriter.All }

procedure TTODOWriter.Flush;
begin
  if assigned(FTODOWriter) then begin
    FTODOWriter.WriteLine(FTODOs.ToStringArray);
    FTODOWriter.Flush;
    FTODOWriter := nil;
  end;
end; { TTODOWriter.Flush }

end.
