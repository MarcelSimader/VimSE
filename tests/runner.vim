" A simple runner for tests in Vim.
"
" To use this runner, place test scripts of the following form into the
" same directory as the runner script:
"
"     ```
"     + dir
"     | runner.vim
"     | test_name.vim
"     L test_another_name.vim
"     ```
"
" Each file of the form `test_XYZ.vim` is sourced by the runner. The test
" files need to contain functions with the following form:
"
" In `dir/test_name.vim`:
"
"     ``` vimscript
"     function! test_name#t0()
"         ...
"     endfunction
"     ```
"
" In `dir/test_another_name.vim`:
"
"     ``` vimscript
"     function! test_another_name#t0()
"         ...
"     endfunction
"     function! test_another_name#t1()
"         ...
"     endfunction
"     ...
"     ```
"
" Each function with a name of the form `test_XYZ#tN` is executed. Errors
" are displayed in a structured manner. Functions are required to use the
" `!` modifier, since we have to overwrite the functions each time the test
" suite is run. The maximum number of function per test file is set as
" `MAX_NUM_TESTS`, which is `30` per default. This means the highest possible
" value for `N` is `test_XYZ#t30`. We have to do this, as far as I can tell,
" to look for functions inside a foreign script.
"
" Take care to manually source `autoload` scripts if you plan to edit them
" while you run tests. Otherwise, one function will be loaded and kept as
" the old form over multiple runs. (Ask me how I know.)
"
" The functions `test_XYZ#before` and `test_XYZ#after` are run before and/or
" after every test.
"
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 05.02.2023
" (c) Marcel Simader 2023

const g:DEBUG = v:false
const g:MAX_NUM_TESTS = 30
" set test directory for all tests to access, remove trailing /
const g:TEST_DIR = trim(expand('<sfile>:h'), '/', 2)

" gather test files with glob
const s:testfiles = split(glob(g:TEST_DIR.'/test_*'), '\n')
const s:original_verrors = copy(v:errors)

" initialize per-test vars
let g:continue_execution = v:true
let g:current_test = ''

messages clear

" ~~~~~~~~~~~~~~~~~~~~ Auxiliary Functions ~~~~~~~~~~~~~~~~~~~~

function! Stop(text)
    " continue guard
    if !g:continue_execution | return | endif

    redraw
    echohl MoreMsg | echo g:current_test.': '.a:text.' Continue?' | echohl None
    let in = getcharstr()
    " CTRL-C check to stop tests
    if in == "\<C-C>" | let g:continue_execution = v:false | endif
endfunction

" TODO: Write documentation
function! TestBuffer(
            \ func_name,
            \ expected_output, expected_buffer_content, buffer_content,
            \ ...)
    new
    call setline(1, a:buffer_content)

    if g:DEBUG | call Stop('0/1') | endif
    let output = function(a:func_name, a:000)()
    if g:DEBUG | call Stop('1/1') | endif

    " check output
    if !(a:expected_output is v:none)
        call assert_equal(a:expected_output, output)
    endif
    " even with an empty buffer, we have ['']
    if !(a:expected_buffer_content is v:none)
        let expected = (len(a:expected_buffer_content) > 0)
                    \ ? a:expected_buffer_content : ['']
        call assert_equal(expected, getline('.', '$'))
    endif

    bwipeout!
endfunction

" ~~~~~~~~~~~~~~~~~~~~ Main Test Loop ~~~~~~~~~~~~~~~~~~~~

for file in s:testfiles
    " continue guard
    if !g:continue_execution | break | endif

    " initialization
    let tail = fnamemodify(file, ':t')
    let root = fnamemodify(tail, ':r')
    let numerrs = 0

    " source test file
    echomsg 'Executing '.root.'...'
    execute 'source '.file

    " find test functions
    let BeforeFunction = exists('*'.root.'#before') ? function(root.'#before') : (v:none)
    let AfterFunction  = exists('*'.root.'#after')  ? function(root.'#after')  : (v:none)
    let functions = []
    for i in range(g:MAX_NUM_TESTS)
        let name = root.'#t'.string(i)
        if exists('*'.name)
            let functions += [[name, function(name)]]
        endif
    endfor

    " run test functions
    for [testname, TestFunction] in functions
        " continue guard
        if !g:continue_execution | break | endif

        let v:errors = []
        echomsg '  '.testname.'... '

        " execute 'before + test + after'
        let g:current_test = testname
        if !(BeforeFunction is v:none) | call BeforeFunction() | endif
        call TestFunction()
        if !(AfterFunction is v:none)  | call AfterFunction()  | endif
        let g:current_test = ''

        if len(v:errors) > 0
            echohl ErrorMsg
            echon 'FAILED'
            for err in v:errors
                echomsg '    '.substitute(err, '\n\s*', '\n  ', 'g')
                let numerrs += 1
            endfor
        else
            echohl MoreMsg
            echon 'OK'
        endif
        echohl None
    endfor

    " Failed x message
    echohl MoreMsg
    if numerrs > 0
        echo
        echomsg 'Failed '.numerrs
    else
        echomsg 'Failed None :>'
    endif
    echohl None
endfor

let v:errors = s:original_verrors

unlet g:DEBUG
unlet g:MAX_NUM_TESTS
unlet g:TEST_DIR

unlet s:testfiles
unlet s:original_verrors

unlet g:continue_execution
unlet g:current_test

