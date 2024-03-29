" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 05.02.2023
" (c) Marcel Simader 2023

" Force reloading of functions in autoload script
execute 'source '.g:TEST_DIR.'/../autoload/vimsetext.vim'

let s:TestPar = function('TestBuffer', ['vimsetext#SmartSurround', v:none])

" ~~~~~~~~~~~~~~~~~~~~ Tests ~~~~~~~~~~~~~~~~~~~~

" Simple inputs
function! test_smartsurround#t0()
    call s:TestPar([''], [''], 0, 0, 1, 1, [], [], -1)
    call s:TestPar(['Test'], ['Test'], 1, 0, 3, 1, [], [], 1)
    call s:TestPar(['Test'], ['Test'], 1, 1, 1, 7, [], [], -1)
endfunction

" Surround one line with one line
function! test_smartsurround#t1()
    call s:TestPar(['Start!I love you, mom.End!'], ['I love you, mom.'],
                \ 1, 1, 1, -1, ['Start!'], ['End!'], -1)
    call s:TestPar(['I Start!loEnd!ve you, mom.'], ['I love you, mom.'],
                \ 1, 1, 3, 5, ['Start!'], ['End!'], -1)
    call s:TestPar(['I loStart!End!ve you, mom.'], ['I love you, mom.'],
                \ 1, 1, 5, 5, ['Start!'], ['End!'], 4)
endfunction

" Surrund one line with multiple lines
function! test_smartsurround#t2()
    call s:TestPar(['Start!', 'I love you, mom.', 'End!'], ['I love you, mom.'],
                \ 1, 1, 1, -1, ['Start!', ''], ['', 'End!'], -1)
    call s:TestPar(['I loStart!', 've ', 'End!you, mom.'], ['I love you, mom.'],
                \ 1, 1, 5, 8, ['Start!', ''], ['', 'End!'], -1)
    call s:TestPar(['I loStart!', '       ve ', 'End!you, mom.'], ['I love you, mom.'],
                \ 1, 1, 5, 8, ['Start!', ''], ['', 'End!'], 7)
    call s:TestPar(['I love ', 'End!you, mom.'], ['I love you, mom.'],
                \ 1, 1, 1, 8, [], ['', 'End!'], 7)
    call s:TestPar(['I love ', '', 'End!you, mom.'], ['I love you, mom.'],
                \ 1, 1, 5, 8, [], ['', '', 'End!'], -1)
    call s:TestPar(['Start!', '', '', 'I love you, mom.', '', 'End!'], ['I love you, mom.'],
                \ 1, 1, 1, -1, ['Start!', '', '', ''], ['', '', 'End!'], -1)
endfunction

" Surround multiple lines with multiple lines
function! test_smartsurround#t3()
    call s:TestPar(['Start!', 'I love ', 'End!', 'you,', ' mom.'], ['I love ', 'you,', ' mom.'],
                \ 1, 1, 0, -1, ['Start!', ''], ['', 'End!'], -1)
    call s:TestPar(['Start!', '    I love ', 'End!', 'you,', ' mom.'], ['I love ', 'you,', ' mom.'],
                \ 1, 1, 0, -1, ['Start!', ''], ['', 'End!'], 4)
    call s:TestPar(['I love ', '    Start!', '    you,', '    End!', ' mom.'], ['I love ', '    you,', ' mom.'],
                \ 2, 2, 0, -1, ['Start!', ''], ['', 'End!'], 0)
    call s:TestPar(['I love ', 'Start!', '    you,', 'End!', ' mom.'], ['I love ', 'you,', ' mom.'],
                \ 2, 2, 0, -1, ['Start!', ''], ['', 'End!'], 4)
    call s:TestPar(['Start!', 'I love ', 'you,', ' mom.', 'End!'], ['I love ', 'you,', ' mom.'],
                \ 1, 3, 0, -1, ['Start!', ''], ['', 'End!'], -1)
    call s:TestPar(['Start!', '   I love ', '   you,', '    mom.', 'End!'], ['I love ', 'you,', ' mom.'],
                \ 1, 3, 0, -1, ['Start!', ''], ['', 'End!'], 3)
    call s:TestPar(['I Start!', ' love ', ' you,', '  mom.', 'End!'], ['I love ', 'you,', ' mom.'],
                \ 1, 3, 3, -1, ['Start!', ''], ['', 'End!'], 1)
endfunction

" Real-life surround examples
function! test_smartsurround#t4()
    call s:TestPar(['and (map (> 3) [1, 2, 3])'], ['map (> 3) [1, 2, 3]'],
                \ 1, 1, 0, -1, ['and ('], [')'], -1)
    call s:TestPar(['def abc(test: str) -> int:',
               \ '    if len(test) > 0:',
               \ '        return 3',
               \ '    else:',
               \ '        return 1'],
                \ ['def abc(test: str) -> int:',
                \  '    return 3'],
                \ 2, 2, 0, -1, ['if len(test) > 0:', ''], ['', 'else:', '    return 1'], 4)
endfunction

