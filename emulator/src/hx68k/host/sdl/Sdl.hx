package hx68k.host.sdl;

@:include("render.h")
@:include("events.h")
extern class Sdl {
	public static inline final EVENT_NONE = 0;
	public static inline final EVENT_QUIT = 1;
	public static inline final EVENT_KEY_DOWN = 2;
	public static inline final EVENT_KEY_UP = 3;
	public static inline final EVENT_MOUSE_MOVE = 4;
	public static inline final EVENT_MOUSE_DOWN = 5;
	public static inline final EVENT_MOUSE_UP = 6;
	public static inline final EVENT_MOUSE_WHEEL = 7;
	public static inline final EVENT_WINDOW_CLOSE = 8;
	public static inline final EVENT_WINDOW_RESIZED = 9;
	public static inline final EVENT_WINDOW_FOCUS_LOST = 10;
	public static inline final EVENT_WINDOW_FOCUS_GAINED = 11;
	public static inline final EVENT_TEXT = 12;

	@:native("host_sdl_init")
	public static function init():Int;

	@:native("host_sdl_quit")
	public static function quit():Void;

	@:native("host_poll_event")
	public static function pollEvent(out:cpp.RawPointer<Event>):Int;

	@:native("host_pad_open")
	public static function padOpen():Int;

	@:native("host_pad_state")
	public static function padState():Int;

	@:native("host_pad_raw")
	public static function padRaw():Int;

	@:native("host_pad_close")
	public static function padClose():Void;

	@:native("host_event_text")
	public static function eventText(event:cpp.RawConstPointer<Event>):cpp.ConstCharStar;

	@:native("host_window_create")
	public static function createWindow(title:cpp.ConstCharStar, width:Int, height:Int):cpp.Star<Window>;

	@:native("host_window_destroy")
	public static function destroyWindow(window:cpp.Star<Window>):Void;

	@:native("host_window_id")
	public static function windowID(window:cpp.Star<Window>):Int;

	@:native("host_window_set_title")
	public static function setWindowTitle(window:cpp.Star<Window>, title:cpp.ConstCharStar):Void;

	@:native("host_window_width")
	public static function windowWidth(window:cpp.Star<Window>):Int;

	@:native("host_window_height")
	public static function windowHeight(window:cpp.Star<Window>):Int;

	@:native("host_window_pixel_width")
	public static function windowPixelWidth(window:cpp.Star<Window>):Int;

	@:native("host_window_pixel_height")
	public static function windowPixelHeight(window:cpp.Star<Window>):Int;

	@:native("host_window_set_size")
	public static function setWindowSize(window:cpp.Star<Window>, width:Int, height:Int):Void;

	@:native("host_window_set_minimum_size")
	public static function setWindowMinimumSize(window:cpp.Star<Window>, width:Int, height:Int):Void;

	@:native("host_window_set_fullscreen")
	public static function setWindowFullscreen(window:cpp.Star<Window>, on:Int):Void;

	@:native("host_window_display_scale")
	public static function windowDisplayScale(window:cpp.Star<Window>):Single;

	@:native("host_text_input_start")
	public static function startTextInput(window:cpp.Star<Window>):Void;

	@:native("host_text_input_stop")
	public static function stopTextInput(window:cpp.Star<Window>):Void;

	@:native("host_renderer_create")
	public static function createRenderer(window:cpp.Star<Window>, vsync:Int):cpp.Star<Canvas>;

	@:native("host_display_refresh")
	public static function displayRefresh(window:cpp.Star<Window>):Single;

	@:native("host_renderer_name")
	public static function rendererName(renderer:cpp.Star<Canvas>):cpp.ConstCharStar;

	@:native("host_renderer_vsync")
	public static function rendererVsync(renderer:cpp.Star<Canvas>):Int;

	@:native("host_renderer_destroy")
	public static function destroyRenderer(renderer:cpp.Star<Canvas>):Void;

	@:native("host_render_clear")
	public static function renderClear(renderer:cpp.Star<Canvas>, r:Single, g:Single, b:Single,
		a:Single):Void;

	@:native("host_render_present")
	public static function renderPresent(renderer:cpp.Star<Canvas>):Void;

	@:native("host_set_clip")
	public static function setClip(renderer:cpp.Star<Canvas>, x:Int, y:Int, width:Int, height:Int):Void;

	@:native("host_clear_clip")
	public static function clearClip(renderer:cpp.Star<Canvas>):Void;

	@:native("host_texture_create")
	public static function createTexture(renderer:cpp.Star<Canvas>, width:Int, height:Int):cpp.Star<Texture>;

	@:native("host_texture_update")
	public static function updateTexture(texture:cpp.Star<Texture>, rgba:cpp.RawPointer<cpp.UInt8>,
		width:Int, height:Int):Void;

	@:native("host_texture_destroy")
	public static function destroyTexture(texture:cpp.Star<Texture>):Void;

	@:native("host_render_texture")
	public static function renderTexture(renderer:cpp.Star<Canvas>, texture:cpp.Star<Texture>,
		dstX:Single, dstY:Single, dstWidth:Single, dstHeight:Single):Void;

	@:native("host_render_texture_region")
	public static function renderTextureRegion(renderer:cpp.Star<Canvas>, texture:cpp.Star<Texture>,
		srcWidth:Single, srcHeight:Single, dstX:Single, dstY:Single, dstWidth:Single, dstHeight:Single):Void;

	@:native("host_render_geometry")
	public static function renderGeometry(renderer:cpp.Star<Canvas>, texture:cpp.Star<Texture>,
		vertices:cpp.RawPointer<Single>, vertexCount:Int):Void;

	@:native("host_open_file_dialog")
	public static function openFileDialog(window:cpp.Star<Window>, filterName:cpp.ConstCharStar,
		pattern:cpp.ConstCharStar):cpp.ConstCharStar;
}
