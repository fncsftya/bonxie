#include "../../include/bonxie_harper.h"
#include <assert.h>
#include <stddef.h>
#include <string.h>

/* Called by an Ada task, just like the production binding. */
void check_harper_abi(void)
{
    static bh_result result;
    const uint8_t invalid[] = {0xff};
    assert(sizeof(bh_suggestion) == 268);
    assert(sizeof(bh_lint) == 1616);
    assert(sizeof(bh_result) == 206856);
    assert(bonxie_harper_check(NULL, 0, BH_BRITISH, BH_PLAIN_TEXT, NULL) == BH_INVALID_ARGUMENT);
    memset(&result, 0xff, sizeof(result));
    assert(bonxie_harper_check(NULL, 1, BH_BRITISH, BH_PLAIN_TEXT, &result) == BH_INVALID_ARGUMENT);
    assert(result.count == 0 && result.truncated == 0);
    assert(bonxie_harper_check(NULL, 0, 99, BH_PLAIN_TEXT, &result) == BH_INVALID_ARGUMENT);
    assert(bonxie_harper_check(NULL, 0, BH_BRITISH, 99, &result) == BH_INVALID_ARGUMENT);
    assert(bonxie_harper_check(invalid, BH_MAX_TEXT + 1, BH_BRITISH,
                              BH_PLAIN_TEXT, &result) == BH_INVALID_ARGUMENT);
    assert(bonxie_harper_check(invalid, 1, BH_BRITISH, BH_PLAIN_TEXT, &result) == BH_INVALID_UTF8);
    assert(result.count == 0 && result.truncated == 0);
    assert(bonxie_harper_check(NULL, 0, BH_BRITISH, BH_PLAIN_TEXT, &result) == BH_OK);
    assert(result.count == 0);
}
