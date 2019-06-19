unit S4L.Captions;

interface

uses
  System.Generics.Collections;

type
  TCaptionInfo = record
    Caption  : string;
    Reference: string;
    TableName: string;
    constructor Create(const ACaption, AReference, ATableName: string);
  end; { TCaptionInfo }

  ICaptions = interface ['{6E3671C1-456A-4714-9F39-86E9247FF74D}']
    procedure Add(const captionText, anchor, tableName: string);
    function GetEnumerator: TList<TCaptionInfo>.TEnumerator;
  end; { ICaptions }

function CreateCaptions: ICaptions;

implementation

uses
  System.SysUtils;

type
  TCaptions = class(TInterfacedObject, ICaptions)
  strict private
    FCaptionList: TList<TCaptionInfo>;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(const captionText, anchor, tableName: string);
    function GetEnumerator: TList<TCaptionInfo>.TEnumerator;
  end; { TCaptions }

{ exports }

function CreateCaptions: ICaptions;
begin
  Result := TCaptions.Create;
end; { CreateCaptions }

{ TCaptionInfo }

constructor TCaptionInfo.Create(const ACaption, AReference, ATableName: string);
begin
  Caption := ACaption;
  Reference := AReference;
  TableName := ATableName
end; { TCaptionInfo.Create }

{ TCaptions }

constructor TCaptions.Create;
begin
  inherited Create;
  FCaptionList := TList<TCaptionInfo>.Create;
end; { TCaptions.Create }

destructor TCaptions.Destroy;
begin
  FreeAndNil(FCaptionList);
  inherited Destroy;
end; { TCaptions.Destroy }

procedure TCaptions.Add(const captionText, anchor, tableName: string);
begin
  FCaptionList.Add(TCaptionInfo.Create(captionText, anchor, tableName));
end; { TCaptions.Add }

function TCaptions.GetEnumerator: TList<TCaptionInfo>.TEnumerator;
begin
  Result := FCaptionList.GetEnumerator;
end; { TCaptions.GetEnumerator }

end.
