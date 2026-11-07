# Python quick-start - fixing common syntax errors

Seeing SyntaxError / NameError? Here are the usual causes and fixes. Type the
examples at the Python prompt (>>>). Open one from the menu (right-click or F12) -> "Python: start ...".

## 1. `=` assigns, `==` compares
- `x = 40`   sets x to 40 (assignment)
- `x == 40`  asks "is x equal to 40?" -> True / False (comparison)
An `if` must use `==`:
    WRONG:  if 40 = x:
    RIGHT:  if x == 40:

## 2. `if` needs a colon `:` and an indented body on the NEXT line
    WRONG:  if x == 40 print("yes")
    RIGHT:
        if x == 40:
            print("yes")
The spaces before `print` are the indentation - that is how Python knows what
is "inside" the if.

## 3. `print` needs parentheses in Python 3
    WRONG:  print "hello"
    RIGHT:  print("hello")

## 4. Text needs quotes; a bare word is read as a name
    >>> hello
    NameError: name 'hello' is not defined
    >>> print("hello")
    hello

## 5. The interactive prompt (REPL)
- `>>>` starts a new statement; `...` means Python wants more (you are in a block).
- After an indented block, press Enter on a BLANK line to run it.
- A variable name alone shows its value:
    >>> x = 40
    >>> x
    40

## A full correct example
    >>> x = 40
    >>> y = 8
    >>> if x == 40:
    ...     print("match!")
    ...
    match!
    >>> if x == y:
    ...     print("equal")
    ... else:
    ...     print("different")
    ...
    different
