#!/bin/bash

step() {
    echo -n "> $@..."

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}
