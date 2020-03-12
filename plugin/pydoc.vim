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
	let g:pydoc_detect_version = 1
endif

if !exists('g:pydoc_open_cmd')
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

	" Grab the cmd from the buffer requesting pydoc.
	let l:pydoc_cmd = get(b:, 'pydoc_cmd', get(t:, 'pydoc_cmd', g:pydoc_cmd))

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
	let s:cmd = l:pydoc_cmd .' '.l:pydoc_options.' '. shellescape(l:name)
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
		let b:pydoc_name = l:name
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

function! s:PyDoc(string)
	return s:ShowPyDoc(a:string, 1)
endfunction
function! s:PyDocGrep(string)
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

function! s:PyDocWrapper()
	let l:iskeyword_orig = &iskeyword
	let &l:iskeyword .= ',.'

	let l:search_term = ''
	let l:line = getline('.')
	let l:col  = col('.')
	let l:current_word = expand('<cword>')

	" Pattern: Simple import, can have alias
	" Location: Import lines
	" TODO: s:ExpandModulePath
	let l:match = matchlist(l:line, '\V\^\s\*import\s\+\(\w\+\)\(\s\+as\s\+\(\w\+\)\|\$\)')
	if l:search_term == '' && !empty(l:match)
		" Search for the unaliased packages name
		let l:search_term = l:match[1]
	endif
	" Pattern: Simple multiple imports
	" Location: Import lines
	" TODO: s:ExpandModulePath
	let l:match = matchlist(l:line, '\v^import (%(\k|[, ])+)$')
	if l:search_term == '' && !empty(l:match)
		if l:current_word ==# 'import'
			" Search for the first package
			let l:search_term = split(l:match[1], '\v, ?')[0]
		else " Cursor on a package
			let l:search_term = l:current_word
		endif
	endif
	" Pattern: Most Complex import
	" Location: Import lines
	" TODO: s:ExpandModulePath
	let l:match = matchlist(l:line, '\v^from (\k+) import (%(\k|[, ]){-})%( as (%(\k|[, ])+))?$')
	if l:search_term == '' && !empty(l:match)
		let l:package = l:match[1]
		if index(['from', l:package], l:current_word) >= 0
			" If inside the keyword or package name
			let l:search_term = l:package
		else " Search for PACKAGE.RIGHT_SIDE
			let l:right_match = '.'
			let l:as_word = l:match[3]
			if index(['import', 'as', l:as_word], l:current_word) >= 0
				" If inside the keywords, search for the first right match
				" Or if the current keyword is on the 'as' section
				let l:right_match .= split(l:match[2], '\v, ?')[0]
			else
				let l:right_match .= l:current_word
			endif
			let l:search_term = l:package.l:right_match
		endif
	endif

	" Pattern: Searching for an aliased module
	" Location: Rest of the code
	if l:search_term == ''
		let l:currentpos = getpos('.')
		let l:hier = split(l:current_word, '\.')
		let l:main_module = l:hier[0]
		let l:regex = '\V\^\s\*\%(from\s\*\(\k\+\)\s\*\)\?import\s\+\%(\('. l:main_module .'\)\$\|\(\k\+\)\s\+as\s\+\%('. l:main_module .'\)\s\*\)'
		if search(l:regex)
			let l:matches = matchlist(getline('.'), l:regex)
			let l:package = l:matches[2] . l:matches[3] "Only one is filled
			if l:matches[1] != ''
				let l:package = l:matches[1]. '.' .l:package
			endif
			let l:hier[0] = l:package
		endif
		let l:search_term = join(l:hier, '.')
		call setpos('.', l:currentpos)
	endif
	" Other patterns: regular middle-of-the-code search
	" TODO: Parse the imports?
	" TODO: s:ExpandModulePath
	if l:search_term == ''
		let l:search_term = l:current_word
	endif

	let &l:iskeyword = l:iskeyword_orig
	if l:search_term !=# ''
		call s:PyDoc(l:search_term)
	else
		echo 'No matching search'
	endif
endfunction

" External Interface
command! -nargs=1 PyDoc     call <SID>PyDoc(<f-args>)
" q-args turn all the arguments into a single quoted string
command! -nargs=* PyDocGrep call <SID>PyDocGrep(<q-args>)

nnoremap <silent> <Plug>(PyDocK) :<C-u>call <SID>PyDocWrapper()<CR>
" vim:set ts=2 sw=2
