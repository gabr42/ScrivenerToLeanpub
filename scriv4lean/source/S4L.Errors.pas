unit S4L.Errors;

interface

type
  IErrorBase = interface ['{CD2B17FA-AAB2-4017-8044-8C52F01F2F1A}']
    function GetErrorMsg: string;
  //
    property ErrorMsg: string read GetErrorMsg;
  end; { IErrorBase }

  TErrorBase = class(TInterfacedObject, IErrorBase)
  strict private
    FErrorMsg: string;
  strict protected
    function  GetErrorMsg: string;
  protected
    function  SetError(const errorMsg: string): boolean; overload; virtual;
    function  SetError(const errorMsg: string; const params: array of const): boolean; overload;
  public
    property ErrorMsg: string read GetErrorMsg;
  end; { TErrorBase }

implementation

uses
  System.SysUtils,
  S4L.Platform;

{ TErrorBase }

function TErrorBase.GetErrorMsg: string;
begin
  Result := FErrorMsg;
end; { TErrorBase.GetErrorMsg }

function TErrorBase.SetError(const errorMsg: string): boolean;
begin
  if FErrorMsg = '' then
    FErrorMsg := errorMsg
  else
    FErrorMsg := FErrorMsg + TPlatform.NewLineDelim + errorMsg;
  Result := false;
end; { TErrorBase.SetError }

function TErrorBase.SetError(const errorMsg: string;
  const params: array of const): boolean;
begin
  Result := SetError(Format(errorMsg, params));
end; { TErrorBase.SetError }

end.
