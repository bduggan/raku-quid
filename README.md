[![Actions Status](https://github.com/bduggan/raku-quid/actions/workflows/linux.yml/badge.svg)](https://github.com/bduggan/raku-quid/actions/workflows/linux.yml)
[![Actions Status](https://github.com/bduggan/raku-quid/actions/workflows/macos.yml/badge.svg)](https://github.com/bduggan/raku-quid/actions/workflows/macos.yml)

NAME
====

Quid -- Raku notebooks for data exploration

SYNOPSIS
========

Usage: quid -- Browse pages quid new -- Open a new page for editing quid edit <name> -- Edit a page with the given name quid reset-conf -- Reset the configuration to the default quid conf -- Edit the configuration file

DESCRIPTION
===========

Quid is a console application for data exploration and analysis.

It has some similarities to other notebooks like Wolfram, R, Jupyter and Observable, but is a but more in line with the Raku programming langauge and adheres to the philosophy of being "opinionated about being not opinionated" and trying stich together various other languages. Here's a quick example:

    -- bash
    echo "a,b,c" > out.csv
    echo "1,2,3" >> out.csv
    echo "done!"

    -- duck
    select * from 'out.csv';

    -- python
    print("hello world")

    -- ruby
    puts "hello world"

    -- html
    <p>
    <pre>
    python says:
    <<< cells(2).content >>>
    <<< cells(2).out >>>

    and ruby says
    <<< cells(3).content >>>
    <<< cells(3).out >>>
    </pre>

Some of its features:

* Notebooks (called "pages") are plain text. Pages are divided into cells. Lines starting with two dashes ("--") divide a page into cells.

* Cell output are defined by plugins, and every output is stored as a file within the data directory for the page.

* Cell types are defined by a configuration file, and new cell types can be easily added with the cell plugin architecture.

* Displaying outputs of cells is also done with a plugout architectures, and new output/export options can be added as plugins.

CONFIGURATION
=============

Quid comes with a default configuration file, it looks like this

    # quid-conf.raku
    #
    %*quid-conf =
      plugins => [
        / duck /   => 'Quid::Plugin::Duck',
        / llm  /   => 'Quid::Plugin::LLM',
        / text /   => 'Quid::Plugin::Text',
        / bash /   => 'Quid::Plugin::Bash',
        / html/    => 'Quid::Plugin::HTML',
      ],
      plugouts => [
        / csv  /   => 'Quid::Plugout::Duckview',
        / csv  /   => 'Quid::Plugout::DataTable',
        / html /   => 'Quid::Plugout::HTML',
        / .*   /   => 'Quid::Plugout::Raw',
      ]
    ;

Inputs (plugins) and outputs (plugouts) are defined by regular expressions which are applied to the first word after the "--" that starts a cell. Defining new plugins is a matter of writing a module that produces output. This can also be done inline for simple cases, e.g. here are two plugins for handling python and ruby cells:

    use Quid::Plugin::Process;

    %*quid-conf =
      plugins => [
        / duck /   => 'Quid::Plugin::Duck',
        / llm  /   => 'Quid::Plugin::LLM',
        / text /   => 'Quid::Plugin::Text',
        / bash /   => 'Quid::Plugin::Bash',
        / html /   => 'Quid::Plugin::HTML',
        / python / => class QuidPython does Quid::Plugin::Process[
                       name => 'python',
                       cmd => 'python3' ] {
           has %.add-env = PYTHONUNBUFFERED => '1';
          },
        / ruby /   => class QuidRuby does Quid::Plugin::Process[
                       name => 'ruby',
                       cmd => 'ruby' ] { },
      ],
      plugouts => [
        / csv  /   => 'Quid::Plugout::Duckview',
        / csv  /   => 'Quid::Plugout::DataTable',
        / html /   => 'Quid::Plugout::HTML',
        / .*   /   => 'Quid::Plugout::Raw',
      ]
    ;

EXAMPLES
--------

More examples!

Sample page 1:

    -- duck
    select 42 as the_answer;

    -- llm
    What is the question if 〈prev.rows[0]<the_answer> 〉 is the answer?

    -- html
    First cell output was 〈cells(0).rows[0]<the_answer> 〉.

This page has two cells. The first is a duckdb query, the second is an LLM query.

After running the first, a CSV file is created. Refreshing the page updates the second one to look like this:

    -- duck
    select 42 as the_answer;

    -- llm
    What is the question if 42 is the answer?

Then running the second sends a query to an LLM.

The symbols "〈" and "〉" are used to indicate code that should be evaluated. You can also use "<<<" and ">>>". Pro tip: if you use vim, you can type "〈" using a digraph: type "control-k" and then "<" and "/".

Here's an example using the python plugin defined above:

    -- llm

    How do I print a python df to a csv?  be concise

    -- python

    import pandas as pd
    import os
    print(os.getcwd())
    df = pd.DataFrame( { 'a': [1,2,3,4], 'b': [5,6,7,8] } )
    df.to_csv('out.csv')
    print(df)

    -- duck

    select * from 'out.csv'

    -- python
    import pandas as pd
    import matplotlib.pyplot as plt
    df = pd.read_csv('out.csv')
    df.plot(kind='bar', x='a', y='b')
    plt.savefig('plot.png')
    plt.show()
    plt.close()
    df

    -- html
    <h2>data</h2>
    <p>
    <img src='plot.png'>
    </p>
    <pre>
    code:
    〈 cells(1).content 〉
    </pre>

