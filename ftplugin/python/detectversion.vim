if exists('g:pydoc_detect_version') && !g:pydoc_detect_version
	"Either this whole thing is completed, or the user overrode it
	finish
endif

" Detect the version based on the shebang
let shebang = getline(1)
" Lax regex, to work on bare binary and env and whatever
if shebang =~# '\<python3\>'
	let new_cmd = substitute(g:pydoc_cmd, '\v<(python|pydoc) ', '\13 ', '')
else
	let new_cmd = substitute(g:pydoc_cmd, '\v<(python|pydoc)3>', '\1', '')
endif

" Change the command
" Just clobber the buffer, it's good to have the lastest info
" For the tab variable, don't clobber
let b:pydoc_cmd = new_cmd
if !exists('t:pydoc_cmd')
	let t:pydoc_cmd = new_cmd
endif
