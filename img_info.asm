#-------------------------------------------------------------------------------
#author: Rajmund Kozuszek
#date : 2024-04-26
#description : example RISC V program for reading, modifying and writing a BMP file
#-------------------------------------------------------------------------------

# for purpose of this example I define structure which will contain important
# bitmap data for image read from the bmp file. Its C definition could be:
#	struct {
#		char* filename;		// pointer to the filename
#		unsigned char* hdrData; // pointer to the bitmapheader (with the colour lookup table)
#		unsigned char* imgData; // pointer to the first image pixel in the memory
#		int width, height;	// width and height of the image in pixels
#		int linebytes;		// size of the image line in bytes
#		int bpp;		// number of bits per pixel (1 or 4)
#	} imgInfo;

.eqv ImgInfo_fname		0
.eqv ImgInfo_hdrdat 	4
.eqv ImgInfo_imdat		8
.eqv ImgInfo_width		12
.eqv ImgInfo_height		16
.eqv ImgInfo_bpp		20	# bits per pixel (either 1 or 4)
.eqv ImgInfo_lbytes		24

.eqv MAX_IMG_SIZE 		12288	# 2048

# more information about bmp format: https://en.wikipedia.org/wiki/BMP_file_format
.eqv BMPHeader_Size 54
.eqv BMPHeader_width_offset 18
.eqv BMPHeader_height_offset 22
.eqv BMPHeader_bpp_offset 28


.eqv system_OpenFile	1024
.eqv system_ReadFile	63
.eqv system_WriteFile	64
.eqv system_CloseFile	57
.eqv system_GetTime		30
.eqv system_PrintString	4
.eqv system_PrintInt	1

