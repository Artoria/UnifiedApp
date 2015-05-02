$: << "../lib"
require 'ua'

class SimpleWin32Application < Ua::Application
  def initialize
  	    super
		stream "com.ua.root", "com.win32.runner"
		add "com.win32.runner" do
			"<% 
			   context('com.win32.cpp', :write) 
			   cflags = context(get('com.win32.cflags'), :shellwords)
			   ldflags = context(get('com.win32.ldflags'), :shellwords) 
			   arr = ['g++', 'com.win32.cpp'] +  cflags +  ldflags
			   context(arr, :shell)
			   context(['win32.exe'], :shell)
			 %>
			"
		end
		add "com.win32.cpp" do
			DATA.read
		end
		add 'com.win32.cflags'
		add 'com.win32.ldflags'
		add 'com.win32.buttons'
		append 'com.win32.ldflags', '-o', 'win32.exe'
		context UAClass, :shellwords do |a|
		  get(a.stream_)
		end
		context Array, :shell do |a|
		  `#{a.join(' ')}`
		end
		context Array, :bound do |a|
		  "#{a.join(",")}"
		end
		context String, :write do |a|
		   IO.binwrite(a, app(a))
		end
		context String, :cstring do |str|
		  str.inspect
		end
		add "com.win32.button" do 
  			%{
     			CreateWindowEx(0, "button", <%= context(text, :cstring) %>, WS_CHILD | WS_VISIBLE,
	                             <%= context(bound, :bound) %>,
								 main, (HMENU)<%= id %>, 0, 0);
	       
  			}
		end

		add "com.win32.buttonclicks" do
			%{
	  		<% get(stream_).each{|obj| %>
				if(LOWORD(w) == <%= obj.id %>){
					MessageBox(0, <%= context(obj.msg, :cstring) %>, 0, 48);
				}
	  		<% } %>
			}
		end
	end
	
	def button(x, y, w, h, text, msg)
	  btn = create 'com.win32.button'
	  @id ||= 100
	  @id += 1
	  btn.bound, btn.text, btn.msg, btn.id = [x, y, w, h], text, msg, @id
	  append 'com.win32.buttons', btn
	  append 'com.win32.buttonclicks', btn
	  btn
	end
end


x = SimpleWin32Application.new
x.get('com.win32.cpp').title = "Hello world"
x.get('com.win32.cpp').bound = [300, 200, 640, 480]
x.button 0, 0, 24, 36, "Hello", "Clicked"
require 'awesome_print'
ap x.instance_eval{@store}
x.go!

__END__
#include <windows.h>
LRESULT CALLBACK wndproc(HWND h, UINT m, WPARAM w, LPARAM l){
	if(m == WM_CLOSE || m == WM_QUIT || m == WM_DESTROY){
	   PostQuitMessage(0);
	   return 0;
	}
	if(m == WM_COMMAND){
		if(HIWORD(w) == BN_CLICKED){
			<%= context(get("com.win32.buttonclicks"), :app) %>
		}
	}
	return DefWindowProc(h, m, w, l);
}

WNDCLASSEX wc = {sizeof(wc), CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS, wndproc, 0, 0, 0, LoadIcon(0, IDI_APPLICATION), LoadCursor(0, IDC_ARROW), (HBRUSH)1, "", "Hello",  LoadIcon(0, IDI_APPLICATION)};
int main(){
	RegisterClassEx(&wc);
	HWND main = CreateWindowEx(0, "Hello", <%= context(title, :cstring) %>, WS_OVERLAPPEDWINDOW | WS_VISIBLE,
							   <%= context(bound, :bound) %>,
							   0, 0, 0, 0
							  );
	<%= context(get('com.win32.buttons'), :app) %>
    MSG msg;
	while(GetMessage(&msg, 0, 0, 0) > 0){
		DispatchMessage(&msg);
		TranslateMessage(&msg);
	}
}