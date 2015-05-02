#include <windows.h>
LRESULT CALLBACK wndproc(HWND h, UINT m, WPARAM w, LPARAM l){
	if(m == WM_CLOSE || m == WM_QUIT || m == WM_DESTROY){
	   PostQuitMessage(0);
	   return 0;
	}
	if(m == WM_COMMAND){
		if(HIWORD(w) == BN_CLICKED){
			
	  		
				if(LOWORD(w) == 101){
					MessageBox(0, "Clicked", 0, 48);
				}
	  		
			
		}
	}
	return DefWindowProc(h, m, w, l);
}

WNDCLASSEX wc = {sizeof(wc), CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS, wndproc, 0, 0, 0, LoadIcon(0, IDI_APPLICATION), LoadCursor(0, IDC_ARROW), (HBRUSH)1, "", "Hello",  LoadIcon(0, IDI_APPLICATION)};
int main(){
	RegisterClassEx(&wc);
	HWND main = CreateWindowEx(0, "Hello", "Hello world", WS_OVERLAPPEDWINDOW | WS_VISIBLE,
							   300,200,640,480,
							   0, 0, 0, 0
							  );
	
     			CreateWindowEx(0, "button", "Hello", WS_CHILD | WS_VISIBLE,
	                             0,0,24,36,
								 main, (HMENU)101, 0, 0);
	       
  			
    MSG msg;
	while(GetMessage(&msg, 0, 0, 0) > 0){
		DispatchMessage(&msg);
		TranslateMessage(&msg);
	}
}