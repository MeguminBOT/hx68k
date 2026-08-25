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

	@:native("host_sdl_init")
	public static function init():Int;

	@:native("host_sdl_quit")
	public static function quit():Void;

	@:native("host_poll_event")
	public static function pollEvent(out:cpp.RawPointer<HostEvent>):Int;

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

	@:native("host_renderer_create")
	public static function createRenderer(window:cpp.Star<Window>, vsync:Int):cpp.Star<Renderer>;

	@:native("host_display_refresh")
	public static function displayRefresh(window:cpp.Star<Window>):Single;

	@:native("host_renderer_name")
	public static function rendererName(renderer:cpp.Star<Renderer>):cpp.ConstCharStar;

	@:native("host_renderer_vsync")
	public static function rendererVsync(renderer:cpp.Star<Renderer>):Int;

	@:native("host_renderer_destroy")
	public static function destroyRenderer(renderer:cpp.Star<Renderer>):Void;

	@:native("host_render_clear")
	public static function renderClear(renderer:cpp.Star<Renderer>, r:Single, g:Single, b:Single,
		a:Single):Void;

	@:native("host_render_present")
	public static function renderPresent(renderer:cpp.Star<Renderer>):Void;

	@:native("host_set_clip")
	public static function setClip(renderer:cpp.Star<Renderer>, x:Int, y:Int, width:Int, height:Int):Void;

	@:native("host_clear_clip")
	public static function clearClip(renderer:cpp.Star<Renderer>):Void;

	@:native("host_texture_create")
	public static function createTexture(renderer:cpp.Star<Renderer>, width:Int, height:Int):cpp.Star<Texture>;

	@:native("host_texture_update")
	public static function updateTexture(texture:cpp.Star<Texture>, rgba:cpp.RawPointer<cpp.UInt8>,
		width:Int, height:Int):Void;

	@:native("host_texture_destroy")
	public static function destroyTexture(texture:cpp.Star<Texture>):Void;

	@:native("host_render_texture")
	public static function renderTexture(renderer:cpp.Star<Renderer>, texture:cpp.Star<Texture>,
		dstX:Single, dstY:Single, dstWidth:Single, dstHeight:Single):Void;

	@:native("host_render_texture_region")
	public static function renderTextureRegion(renderer:cpp.Star<Renderer>, texture:cpp.Star<Texture>,
		srcWidth:Single, srcHeight:Single, dstX:Single, dstY:Single, dstWidth:Single, dstHeight:Single):Void;

	@:native("host_render_geometry")
	public static function renderGeometry(renderer:cpp.Star<Renderer>, texture:cpp.Star<Texture>,
		vertices:cpp.RawPointer<Single>, vertexCount:Int):Void;

	@:native("host_open_file_dialog")
	public static function openFileDialog(window:cpp.Star<Window>, filterName:cpp.ConstCharStar,
		pattern:cpp.ConstCharStar):cpp.ConstCharStar;
}
