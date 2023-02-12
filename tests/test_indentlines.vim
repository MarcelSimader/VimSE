" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 06.02.2023
" (c) Marcel Simader 2023

" Force reloading of functions in autoload script
execute 'source '.g:TEST_DIR.'/../autoload/vimse.vim'

let s:expr0 =<< eval END
This is a test.
  and we test it,
   using tests.
Yup.
{"\t"}Yup
END

let s:expr1 =<< eval END
{"\t"}{"\t"}Yup{"\t"} does not matter here
{"\t"}  But it does here!
   Yes...{"\t"}
END

" ~~~~~~~~~~~~~~~~~~~~ Pre ~~~~~~~~~~~~~~~~~~~~

function! test_indentlines#before()
    " Force a certain shift-width
    setlocal shiftwidth=4
endfunction

function! test_indentlines#after()
    set shiftwidth<
endfunction

" ~~~~~~~~~~~~~~~~~~~~ Tests ~~~~~~~~~~~~~~~~~~~~

" Zero indent on examples
function! test_indentlines#t0()
    let expected =<< END
This is a test.
  and we test it,
   using tests.
Yup.
    Yup
END
    call assert_equal(expected, vimse#IndentLines(s:expr0, 0))

    let expected =<< eval END
     Yup{"\t"} does not matter here
   But it does here!
Yes...{"\t"}
END
    call assert_equal(expected, vimse#IndentLines(s:expr1, 0))
endfunction

" Single space indent on examples
function! test_indentlines#t1()
    let expected =<< END
 This is a test.
   and we test it,
    using tests.
 Yup.
     Yup
END
    call assert_equal(expected, vimse#IndentLines(s:expr0, 1))

    let expected =<< eval END
      Yup{"\t"} does not matter here
    But it does here!
 Yes...{"\t"}
END
    call assert_equal(expected, vimse#IndentLines(s:expr1, 1))
endfunction

" Ranged 4-space indent on examples
function! test_indentlines#t2()
    let expected =<< eval END
This is a test.
      and we test it,
       using tests.
    Yup.
{"\t"}Yup
END
    call assert_equal(expected, vimse#IndentLines(s:expr0, 4, 1, 3))

    let expected =<< eval END
{"\t"}{"\t"}Yup{"\t"} does not matter here
       But it does here!
    Yes...{"\t"}
END
    call assert_equal(expected, vimse#IndentLines(s:expr1, 4, 1, 2))
endfunction

