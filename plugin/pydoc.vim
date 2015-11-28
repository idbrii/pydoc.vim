" Vim ftplugin file
" Language: Python
" Authors:  André Kelpe <efeshundertelf at googlemail dot com>
"           Romain Chossart <romainchossat at gmail dot com>
"           Matthias Vogelgesang
"           Ricardo Catalinas Jiménez <jimenezrick at gmail dot com>
"           Patches and suggestions from all sorts of fine people
"
" More info and updates at:
"
" http://www.vim.org/scripts/script.php?script_id=910
"
"
" This plugin integrates the Python documentation view and search tool pydoc
" into Vim. It allows you to view the documentation of a Python module or class
" by typing:
"
" :Pydoc foo.bar.baz (e.g. :Pydoc re.compile)
"
" Or search a word (uses pydoc -k) in the documentation by typing:
"
" :PydocSearch foobar (e.g. :PydocSearch socket)
"
" Vim will split the current window to show the Python documentation found by
" pydoc, and reuse that window in case you search for other things.
"
" pydoc.vim also allows you to view the documentation of the 'word' (see :help
" word) under the cursor by pressing <Leader>pw or the 'WORD' (see :help WORD)
" under the cursor by pressing <Leader>pW. This is very useful if you want to
" jump to the docs of a module or class found by 'PydocSearch' or if you want
" to see the docs of a module/class in your source code. Additionally K is
" mapped to show invoke pydoc as well, when you are editing python files.
"
" The script is developed in GitHub at:
"
" http://github.com/fs111/pydoc.vim
"
"
" If you want to use the script and pydoc is not in your PATH, just put a
" line like this in your .vimrc:
"
" let g:pydoc_cmd = '/usr/bin/pydoc'
"
" or more portable
"
" let g:pydoc_cmd = 'python -m pydoc'
"
" If you want to open pydoc files in vertical splits or tabs, give the
" appropriate command in your .vimrc with:
"
" let g:pydoc_open_cmd = 'vsplit'
"
" or
"
" let g:pydoc_open_cmd = 'tabnew'
"
" The script will highlight the search term by default. To disable this behaviour
" put in your .vimrc:
"
" let g:pydoc_highlight=0
"
" If you want pydoc to switch to an already open tab with pydoc page,
" set this variable in your .vimrc (uses drop - requires vim compiled with
" gui!):
"
" let g:pydoc_use_drop=1
"
" Pydoc files are open with 10 lines height, if you want to change this value
" put this in your .vimrc:
"
" let g:pydoc_window_lines=15
" or
" let g:pydoc_window_lines=0.5
"
" Float values specify a percentage of the current window.
"
"
" In order to install pydoc.vim download it from vim.org or clone the repository
" on githubi and put it in your .vim/ftplugin directory. pydoc.vim is also fully
" compatible with pathogen, so cloning the repository into your bundle directory
" is also a valid way to install it. (I do this myself. see
" https://github.com/fs111/dotvim).
"
" pydoc.vim is free software; you can redistribute it and/or
" modify it under the terms of the GNU General Public License
" as published by the Free Software Foundation; either version 2
" of the License, or (at your option) any later version.
"
" Please feel free to contact me and follow me on twitter (@fs111).

if exists('g:loaded_pydoc.vim')
	finish
endif
let g:loaded_pydoc = 1

if !exists('g:pydoc_cmd')
	let g:pydoc_cmd = 'pydoc'
endif

if !exists('g:pydoc_new_cmd')
	let g:pydoc_open_cmd = 'vertical new'
endif
if !exists('g:pydoc_existing_cmd')
	let g:pydoc_existing_cmd = 'enew'
endif

function! s:WindowNew()
	execute g:pydoc_open_cmd
endfunction
function! s:WindowOld()
	execute g:pydoc_existing_cmd
endfunction

" Args: name: lookup; type: 0: search, 1: lookup
function! s:ShowPyDoc(name, type)
	if a:name == ''
		return
	endif

	if exists('t:pydoc_buffer')
		let l:winnr = bufwinnr(t:pydoc_buffer)
		if l:winnr != -1 && getwinvar(l:winnr, '&ft') ==# 'pydoc'
			" The window is still being used for pydoc
			" Therefore, reuse it
			execute l:winnr . 'wincmd w'
			call s:WindowOld()
		else
			" The window changed buffers, no reuse
			call s:WindowNew()
		endif
	else
		" PyDoc has never run before, nothing to reuse
		call s:WindowNew()
	endif

	" STATE: a new, empty buffer as current

	" Configure the pydoc buffer
	setlocal noswapfile buftype=nofile nolist
	setlocal bufhidden=delete "If the buffer gets hidden, delete it

	" Remove function/method arguments
	let l:name = substitute(a:name, '(.*', '', 'g' )
	" Remove all colons
	let l:name = substitute(l:name, ':', '', 'g' )

	" The moneyshot
	let l:pydoc_options = ''
	if a:type == 0
		let l:pydoc_options .= ' -k'
	endif
	let s:cmd = g:pydoc_cmd .' '.l:pydoc_options.' '. shellescape(l:name)
	if &verbose
		echomsg "PyDoc: " s:cmd
	endif
	" Read the pydoc to the buffer
	execute  "silent read !" s:cmd
	" The lines read start on the second line, because the first was already
	" there in the empty buffer
	goto "first line
	delete _ "current line, into the black-hole register

	let l:line = getline(1)
	if l:line =~ '^no Python documentation found for.*$'
		" Couldn't find any docs
		" Close the window
		close
		" Warn the user
		redraw
		echom 'PyDoc: ' . l:line
	else
		" SUCESS!
		" Save the current window buffer
		let t:pydoc_buffer = bufnr('%')
		if l:line =~# '^Help on module .*:$' && empty(getline(2))
			let b:pydoc_type = 'module'
			" Delete the header
			normal! "_2dd
		else
			let b:pydoc_type = 'others'
		endif
		setlocal filetype=pydoc nomodifiable
		if exists('#User#PyDoc')
			doautocmd <nomodeline> User PyDoc
		endif
	endif
endfunction

function! PyDoc(string)
	return s:ShowPyDoc(a:string, 1)
endfunction
function! PyDocGrep(string)
	return s:ShowPyDoc(a:string, 0)
endfunction

function! s:ExpandModulePath()
	" Extract the 'word' at the cursor, expanding leftwards across identifiers
	" and the . operator, and rightwards across the identifier only.
	"
	" For example:
	"   import xml.dom.minidom
	"           ^   !
	"
	" With the cursor at ^ this returns 'xml'; at ! it returns 'xml.dom'.
	let l:line = getline(".")
	let l:pre = l:line[:col(".") - 1]
	let l:suf = l:line[col("."):]
	return matchstr(pre, "[A-Za-z0-9_.]*$") . matchstr(suf, "^[A-Za-z0-9_]*")
endfunction

" External Interface
command! -nargs=1 PyDoc     call PyDoc(<f-args>)
" q-args turn all the arguments into a single quoted string
command! -nargs=* PyDocGrep call PyDocGrep(<q-args>)

nnoremap <silent> <buffer> <Plug>(PyDocCurrentModule) :<C-u>call PyDoc(<SID>ExpandModulePath())<CR>
autocmd Filetype pydoc nmap <buffer> K <Plug>(PyDocCurrentModule)

" vim:set ts=2 sw=2
