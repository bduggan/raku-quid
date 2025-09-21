[![Actions Status](https://github.com/bduggan/raku-quid/actions/workflows/linux.yml/badge.svg)](https://github.com/bduggan/raku-quid/actions/workflows/linux.yml)
[![Actions Status](https://github.com/bduggan/raku-quid/actions/workflows/macos.yml/badge.svg)](https://github.com/bduggan/raku-quid/actions/workflows/macos.yml)

NAME
====

Quid -- Query Independent sources of Data

SYNOPSIS
========

    quid
    quid new
    quid edit life

DESCRIPTION
===========

Quid is a console application that uses plugins and plugouts to read and view data.

It has some similarities to Jupyter and other notebook environment, but has some distinctive features:

* Notebooks (called "pages") are plain text. Pages are divided into cells. Lines starting with two dashes ("--") divide a page into cells.

* Cell output are defined by plugins, and every output is stored as a file within the data directory for the page.

* Cells can use other cells outputs by reading those files.

* Cell types are defined by a configuration file, and new cell types can be easily added with the cell plugin architecture.

* Displaying outputs of cells is also done with a plugout architectures, and new output/export options can easily be added as plugins.

Enough description! Here is what it looks like:

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

The symbols "〈" and "〉" are used to indicate code that should be evaluated. You can also use "<<<" and ">>>". Pro typ: type the former with vim, you can use a digraph -- type "control-k" and then "<" and "/".

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

