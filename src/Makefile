all:
	@erlc t.erl
start:
#                  134217727
	erl -noshell +P 10000000 -eval 'L=t:start(),timer:sleep(0),halt().'
debug:
	erl +P 10000000 -eval 't:start().'
clean: 
	rm *.beam
