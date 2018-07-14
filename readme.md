open/read/write any binary file in ProDOS filesystem.<br>
runs from any directory on floppy or hard disk.<br>
searches the file system for the requested file, can even look inside subdirectories.<br>
only 5 sectors long in memory (7 sectors if writing enabled).<br>
<br>
usage:<br>
<br>
jsr init ;one-time call to unhook ProDOS, detect drive type, and relocate code to top of memory<br>
<br>
;open and read a file without address override or writing enabled<br>
lda #<file_to_read<br>
sta namlo<br>
lda #>file_to_read<br>
sta namhi<br>
jsr opendir ;open and read entire file into memory at its load address<br>
<br>
;open and read a file with address override but without writing enabled<br>
lda #<file_to_read<br>
sta namlo<br>
lda #>file_to_read<br>
sta namhi<br>
lda #<place_to_read<br>
sta adrlo<br>
lda #>place_to_read<br>
sta adrhi<br>
jsr opendir ;open and read entire file into memory to the specified load address<br>
<br>
;open and read a subdirectory without address override or writing enabled<br>
lda #<dir_to_read<br>
sta namlo<br>
lda #>dir_to_read<br>
sta namhi<br>
jsr opendir ;open and read subdirectory to top of memory for later<br>
;issue another open request to find a file inside it<br>
lda #<file_to_read<br>
sta namlo<br>
lda #>file_to_read<br>
sta namhi<br>
jsr readdir ;read directory without opening it again<br>
<br>
;open and read a file with writing enabled but without address override<br>
lda #<file_to_read<br>
sta namlo<br>
lda #>file_to_read<br>
sta namhi<br>
lda #1<br>
sta reqcmd<br>
jsr opendir ;open and read entire file into memory at its load address<br>
<br>
;open and write a file without address override<br>
lda #<file_to_write<br>
sta namlo<br>
lda #>file_to_write<br>
sta namhi<br>
lda #0<br>
sta sizelo<br>
lda #>bytes_to_write<br>
sta sizehi<br>
lda #2<br>
jsr opendir ;open and write bytes from memory to file load address<br>
<br>
;open and write a file with address override<br>
lda #<file_to_write<br>
sta namlo<br>
lda #>file_to_write<br>
sta namhi<br>
lda #0<br>
sta sizelo<br>
lda #>bytes_to_write<br>
sta sizehi<br>
lda #<place_to_write<br>
sta adrlo<br>
lda #>place_to_write<br>
sta adrhi<br>
lda #2<br>
jsr opendir ;open and write bytes from memory to specified load address<br>
<br>
<br>
format of request name is Pascal-style (length, text):<br>
e.g. !raw 5, "MYDIR" or !raw 6, "MYFILE" or !raw 14, "QKUMBAROXURSOX"
