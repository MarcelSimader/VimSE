" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 05.02.2024
" (c) Marcel Simader 2024

" Force reloading of functions in autoload script
execute 'source '.g:TEST_DIR.'/../autoload/vimseio.vim'

function! s:Test(fed_input, expected_output,
            \ prompt = '', default = '', complete = v:none, OnChange = v:none)
    const result = vimseio#Input(
                \ a:prompt, a:default, a:complete,
                \ a:OnChange, {-> feedkeys(a:fed_input)}, v:none,
                \ )
    call assert_equal(a:expected_output, result)
endfunction

" ~~~~~~~~~~~~~~~~~~~~ Tests ~~~~~~~~~~~~~~~~~~~~

" Empty examples
function! test_input#t0()
    const def_text = 'Some default text...'
    call s:Test("\<CR>", '')
    call s:Test("\<CR>", '', 'Prompt: ')
    call s:Test("\<CR>", def_text, 'Prompt: ', def_text)
    call s:Test("\<CR>", def_text, 'Prompt: ', def_text, 'file')
    call s:Test("\<CR>", def_text, 'Prompt: ', def_text, 'file', {_, __ -> 0})
    call s:Test("\<CR>", def_text, 'Prompt: ', def_text, 'file', {_, __ -> v:true})
    call s:Test("\<Esc>", v:none)
    call s:Test("\<Esc>", v:none, 'Prompt: ')
    call s:Test("\<Esc>", v:none, 'Prompt: ', def_text)
    call s:Test("\<Esc>", v:none, 'Prompt: ', def_text, 'file')
    call s:Test("\<Esc>", v:none, 'Prompt: ', def_text, 'file', {_, __ -> v:false})
    call s:Test("\<Esc>", v:none, 'Prompt: ', def_text, 'file', {_, __ -> 1})
endfunction

" Simple non-keybind examples
function! test_input#t1()
    call s:Test("This is some input\<CR>", 'This is some input')
    call s:Test("y\<CR>", 'y', 'Complete Operation? [y/n]: ')
    call s:Test("y\<NL>", 'y', 'Complete Operation? [y/n]: ')
    call s:Test("\<Esc>", v:none, 'Complete Operation? [y/n, Esc to abort]: ')
endfunction

" Basic cursor movement examples
function! test_input#t2()
    call s:Test("ABCD\<Left>\<Left>12\<C-J>", 'AB12CD')
    call s:Test("ABCD\<Left>\<Left>12\<C-M>", 'AB12CD', 'Even with prompt')
    call s:Test("ABCD\<Left>\<Left>12\<C-J>", 'AB12CD..', 'Even with prompt', '..')
    call s:Test("ABCD\<End>12\<CR>", 'ABCD..12', 'Even with prompt', '..')
    call s:Test("ABCD\<Left>\<Left>12\<C-M>", 'AB12CD', 'Even with prompt', '', 'file')
    call s:Test("ABCD\<Left>\<Right>12\<CR>", 'ABCD12', 'Even with prompt', '', 'file')
    call s:Test("ABCD\<Home>\<Right>12\<CR>", 'A12BCD', 'Even with prompt', '', 'file')
    call s:Test("ABCD\<C-Left>12\<CR>", '12ABCD', 'Even with prompt', '', 'file')
endfunction

" Advanced cursor movement examples
function! test_input#t3()
    call s:Test("some words here\<C-Left>12\<Left>\<Left>\<S-Left>34\<C-Right>56\<CR>",
                \ 'some 34words56 12here', 'Even with prompt', '', 'file')
    call s:Test("\<End>is what happens if you make a txpo"
                \     .."\<C-Left>\<Right>\<Right>\<BS>y\<CR>",
                \ 'This is what happens if you make a typo', 'Input: ', 'This ', 'file')
    call s:Test("\<End>is what happens if you make a BIG typo"
                \     .."\<C-W>\<C-W>\<C-W>big typod\<BS>s\<CR>",
                \ 'This is what happens if you make big typos', 'Input: ', 'This ')
    call s:Test("A delete example\<Home>\<Del>\<Del>\<Del>\<Del>\<Del>\<CR>",
                \ 'ete example')
    call s:Test("This is a delete until start of line!\<C-Left>\<C-Left>\<C-Left>"
                \     .."\<C-U>\<CR>",
                \ 'start of line!')
endfunction

" Completion system examples
function! test_input#t4()
    function! H(...) | return ['an exmpl', 'another exmpl', 'some nrs 123'] | endfunction
    call s:Test("\<End>\<C-U>\<Tab>\<CR>", 'an exmpl',
                \ 'File: ', 'curr.buffer', 'customlist,H')
    call s:Test("\<End>\<C-U>\<Tab>\<Tab>\<S-Tab>\<Tab>\<CR>", 'another exmpl',
                \ 'File: ', 'curr.buffer', 'customlist,H')
    call s:Test("\<End>\<C-U>\<Tab>\<Tab>\<Tab>\<CR>", 'some nrs 123',
                \ 'File: ', 'curr.buffer', 'customlist,H')
    call s:Test("\<End>\<C-U>\<Tab>\<Tab>\<Tab>\<Tab>\<CR>", '',
                \ 'File: ', 'curr.buffer', 'customlist,H')
    call s:Test("\<End>\<C-U>\<Tab>\<Tab>\<Tab>\<Tab>\<Tab>\<CR>", 'an exmpl',
                \ 'File: ', 'curr.buffer', 'customlist,H')
    call s:Test("\<Tab>\<Tab>\<Tab>\<Tab>\<CR>", 'an', 'File: ', 'an', 'customlist,H')
endfunction
