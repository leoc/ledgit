# Ledgit

Ledgit is a simple script that downloads your transactions from
your online banking interface and writes them into your ledger file.

Before synchronizing it creates an index of transaction partners (whom
consist of transaction partner name, account number and bank code),
from which ledgit chooses the most used ledger account and ledger
transaction name.

## Handlers

You can write handlers for every bank you use. It´s a simple script
for me, so I only implemented the ones I need.

Have a look at `lib/handlers/dkb.rb` to see an example. Basically it´s
just visiting the online banking website with mechanize.

- `dkb` - Handler for dkb.de

## Installation

Juts clone the repository to your home directory and install the
needed gems via bundler.

    git clone git@github.com:leoc/ledgit.git .ledgit
    cd .ledgit
    bundle install
    
Then create a cron, to invoke the script repeatedly.

    0 */4 * * * /home/leoc/.ledgit/bin/ledgit
    
This will update your ledger files every 4 hours.

## Configuration

Your accounts are configured within `~/.ledgit.json`. It´s pretty
self-explanatory. You can copy `ledgit/ledgit-example.json`
to `~/.ledgit.json`
