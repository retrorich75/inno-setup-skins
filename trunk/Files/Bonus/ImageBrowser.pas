unit ImageBrowser;

interface

uses
  Windows, Messages, Classes, Controls, GdiPlus;

const
  FadingTimer = 1;
  DisplayTimer = 2;

type
  TImageChangeEvent = procedure(Sender: TObject; ImageIndex: Integer) of object;

  TCustomImageBrowser = class(TCustomControl)
  private
    FSlideShow: Boolean;
    FCurrIndex: Integer;
    FPrevIndex: Integer;
    FCurrAttrs: IGPImageAttributes;
    FPrevAttrs: IGPImageAttributes;
    FImageList: TInterfaceList;
    FFadingTime: Integer;
    FDisplayTime: Integer;
    FFadingStart: Cardinal;
    FOnImageChanged: TImageChangeEvent;
    procedure WMTimer(var AMessage: TWMTimer); message WM_TIMER;
    function GetNextImageIndex(ImageIndex: Integer): Integer;
    function GetPrevImageIndex(ImageIndex: Integer): Integer;
    procedure SetColorMatrixAlpha(var ImageAttributes: IGPImageAttributes;
      Value: Single);
    procedure StartWaiting;
    procedure StartFading(ImageIndex: Integer);
    procedure DoImageChanged(ImageIndex: Integer);
  protected
    procedure Paint; override;
    property FadingTime: Integer read FFadingTime write FFadingTime default 350;
    property DisplayTime: Integer read FDisplayTime write FDisplayTime default 1500;
    property OnImageChanged: TImageChangeEvent read FOnImageChanged write FOnImageChanged;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddImage(const FileName: string): Integer;
    procedure ClearImages;
    procedure DeleteImage(Index: Integer);
    procedure InsertImage(Index: Integer; const FileName: string);
    procedure FadeImageToNext;
    procedure FadeImageToPrevious;
    procedure FadeImageToIndex(Index: Integer);
    procedure StartSlideshow;
    procedure StopSlideshow;
  end;

  TImageBrowser = class(TCustomImageBrowser)
  published
    property Align;
    property Anchors;
    property FadingTime;
    property DisplayTime;

    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnImageChanged;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
  end;

procedure Register;

implementation

{ TCustomImageBrowser }

constructor TCustomImageBrowser.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 105;
  Height := 105;
  FCurrIndex := -1;
  FPrevIndex := -1;
  FFadingTime := 350;
  FDisplayTime := 1500;
  FImageList := TInterfaceList.Create;
  FCurrAttrs := TGPImageAttributes.Create;
  FPrevAttrs := TGPImageAttributes.Create;
end;

destructor TCustomImageBrowser.Destroy;
begin
  FImageList.Free;
  inherited;
end;

procedure TCustomImageBrowser.Paint;
var
  GPGraphics: IGPGraphics;
begin
  // there's nothing to draw when the current image index is -1
  if FCurrIndex <> -1 then
  begin
    // prepare the GDI+ canvas interface
    GPGraphics := TGPGraphics.Create(Canvas.Handle);
    // if there's some image behind to be seen (fading in progress) then draw it
    if FPrevIndex <> -1 then
      GPGraphics.DrawImage(
        IGPImage(FImageList[FPrevIndex]),
        TGPRect.Create(ClientRect),
        0,
        0,
        IGPImage(FImageList[FPrevIndex]).Width,
        IGPImage(FImageList[FPrevIndex]).Height,
        UnitPixel,
        FPrevAttrs
      );
    // draw the foreground image (always)
    GPGraphics.DrawImage(
      IGPImage(FImageList[FCurrIndex]),
      TGPRect.Create(ClientRect),
      0,
      0,
      IGPImage(FImageList[FCurrIndex]).Width,
      IGPImage(FImageList[FCurrIndex]).Height,
      UnitPixel,
      FCurrAttrs
    );
  end;
end;

function TCustomImageBrowser.GetNextImageIndex(ImageIndex: Integer): Integer;
begin
  // assume the next image index is the first one in the list
  Result := 0;
  // if the index for what is the previous one determined is less than last
  if ImageIndex < FImageList.Count - 1 then
    Result := ImageIndex + 1;
end;

function TCustomImageBrowser.GetPrevImageIndex(ImageIndex: Integer): Integer;
begin
  // assume the previous image index is the last one in the list
  Result := FImageList.Count - 1;
  // if the index for what is the previous one determined is greater than 0
  if ImageIndex > 0 then
    Result := ImageIndex - 1;
end;

procedure TCustomImageBrowser.StartFading(ImageIndex: Integer);
begin
  // that's quite paranoid kill of both fading and display timers
  KillTimer(Handle, DisplayTimer);
  KillTimer(Handle, FadingTimer);
  // shuffle the currently fore image to background (as fade out image)
  FPrevIndex := FCurrIndex;
  // and shuffle the image which is to be displayed to fade in
  FCurrIndex := ImageIndex;
  // store the fading start time
  FFadingStart := GetTickCount;
  // and start the fading timer
  SetTimer(Handle, FadingTimer, 50, nil);
end;

procedure TCustomImageBrowser.StartWaiting;
begin
  // start the slideshow image display timer
  SetTimer(Handle, DisplayTimer, FDisplayTime, nil);
end;

procedure TCustomImageBrowser.DoImageChanged(ImageIndex: Integer);
begin
  // fire the event if assigned
  if Assigned(FOnImageChanged) then
    FOnImageChanged(Self, ImageIndex);
end;

procedure TCustomImageBrowser.StartSlideshow;
begin
  // set the slideshow flag
  FSlideShow := True;
  // and fade to the following image
  StartFading(GetNextImageIndex(FCurrIndex));
end;

procedure TCustomImageBrowser.StopSlideshow;
begin
  // reset the slideshow flag and let the image gently finish fading
  FSlideShow := False;
end;

procedure TCustomImageBrowser.SetColorMatrixAlpha(
  var ImageAttributes: IGPImageAttributes; Value: Single);
var
  GPColorMatrix: TGPColorMatrix;
begin
  // reset the color matrix to the following state
  // [1][0][0][0][0]
  // [0][1][0][0][0]
  // [0][0][1][0][0]
  // [0][0][0][1][0]
  // [0][0][0][0][1]
  GPColorMatrix.SetToIdentity;
  // modify the alpha value of the matrix
  GPColorMatrix.M[3][3] := Value;
  // adjust the color matrix to the passed image attributes
  ImageAttributes.SetColorMatrix(GPColorMatrix, ColorMatrixFlagsDefault,
    ColorAdjustTypeBitmap);
end;

procedure TCustomImageBrowser.WMTimer(var AMessage: TWMTimer);
var
  FadingAlpha: Single;
begin
  case AMessage.TimerID of
    // if the fading timer fired its event
    FadingTimer:
    begin
      FadingAlpha := (GetTickCount - FFadingStart) / FFadingTime;
      // if the time delta reached 1.00 then the fading is done
      if FadingAlpha >= 1.00 then
      begin
        // so kill the fading timer
        KillTimer(Handle, FadingTimer);
        // this is here to stop drawing of the faded-out image in Paint method
        FPrevIndex := -1;
        // reset the color matrices values of the current and previous image
        SetColorMatrixAlpha(FCurrAttrs, 1.00);
        SetColorMatrixAlpha(FPrevAttrs, 0.00);
        // if the slideshow is on the display timer needs to be started
        if FSlideShow then
          SetTimer(Handle, DisplayTimer, FDisplayTime, nil);
        // fire the OnImageChanged event
        DoImageChanged(FCurrIndex);
      end
      // else the fading is in progress
      else
      begin
        // update the color matrices with new values
        SetColorMatrixAlpha(FCurrAttrs, FadingAlpha);
        SetColorMatrixAlpha(FPrevAttrs, 1.00 - FadingAlpha);
      end;
      // and refresh the device context
      Invalidate;
    end;
    // if the display timer fired it event
    DisplayTimer:
    begin
      // stop the slideshow display timer
      KillTimer(Handle, DisplayTimer);
      // if the slideshow is still on, continue to fade the next image
      if FSlideShow then
        StartFading(GetNextImageIndex(FCurrIndex));
    end;
  end;
end;

procedure TCustomImageBrowser.FadeImageToIndex(Index: Integer);
begin
  // if the user doesn't want to fade to the same image that is displayed
  // and if the index is in list bounds then fade to the image index
  if (Index <> FCurrIndex) and (Index > -1) and (Index < FImageList.Count) then
    StartFading(Index);
end;

function TCustomImageBrowser.AddImage(const FileName: string): Integer;
var
  GPImage: IGPImage;
begin
  // create the GDI+ image locally to pass it to the TInterfaceList
  GPImage := TGPImage.Create(FileName);
  // add the image to the list and return its index
  Result := FImageList.Add(GPImage);
  // if there's no image rendered, then render this one
  if FCurrIndex = -1 then
  begin
    // set the foreground image index
    FCurrIndex := Result;
    // set its alpha to 0 (fully visible)
    SetColorMatrixAlpha(FCurrAttrs, 1.00);
    // and force the control to invalidate
    Invalidate;
  end;
end;

procedure TCustomImageBrowser.ClearImages;
begin

end;

procedure TCustomImageBrowser.DeleteImage(Index: Integer);
begin

end;

procedure TCustomImageBrowser.InsertImage(Index: Integer;
  const FileName: string);
begin

end;

procedure TCustomImageBrowser.FadeImageToNext;
begin
  StartFading(GetNextImageIndex(FCurrIndex));
end;

procedure TCustomImageBrowser.FadeImageToPrevious;
begin
  StartFading(GetPrevImageIndex(FCurrIndex));
end;

procedure Register;
begin
  RegisterComponents('InnoSetup Components', [TImageBrowser]);
end;

end.
