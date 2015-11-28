if !exists('g:pydoc_skip_mappings')
	nnoremap <silent> <buffer> K :<C-u>call PyDoc(expand('<cword>'))<CR>
endif
