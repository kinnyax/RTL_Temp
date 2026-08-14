.RECIPEPREFIX := >
.PHONY: list clean

list:
> @for dir in */; do [ -x "$${dir}run_clr" ] && echo "$${dir%/}" || true; done

clean:
> @set -e; for dir in */; do [ -x "$${dir}run_clr" ] || continue; (cd "$$dir" && ./run_clr); done

