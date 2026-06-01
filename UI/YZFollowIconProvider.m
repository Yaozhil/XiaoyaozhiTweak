#import <UIKit/UIKit.h>

UIImage *YZEmbeddedFollowIconImage(void) {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *chunks = @[            @"iVBORw0KGgoAAAANSUhEUgAAADgAAAA4CAYAAACohjseAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAA3fSURBVGhD3ZrZbxvXFcb7t/S1KAq0T30q2qIo+tAWbZAW",
            @"KJACbdIgbdM1aOo0QWI06ZLUjRMvkZfYie1IXuJYsrVYu0VqoSiRlCgu4r4MyeEmktq8y/76nTscmZZlixKpFugBDuZyhkOe3z3nnnvu3Pkc/s9lVwDX1tawXFnEErVSKqOyYOjq8gpu3bxV/dZ/R5oKeP/+fZTL",
            @"ZSwtLuLunbvr51ZXVrBYrqBcKqGYL2ChWMTt27fV9Xv37qnjbklTAUsLC8pgEyqnZ5AMR5BNJlHIpKhppal4DOlEgt68iesrq7h71+iM3ZDmABIon82hmMsjm04hGY0iFYsgE48iHYshFYkir6WQT1U1nUae8Ilg",
            @"GFGfD6N9/fBMOVBmBzVbGgMkWIUhmctm1TEVjUBPxJFLJwkhqj2A2qARglmu9vGeICYGhjE1bIVzdBz+2VncvmWEbzNkx4B37txBgR5bWV5GIhaH2+Fk2MVo/OOhRANzc5i0WjE3NY1UiB4M+eFzOpHjNZ3e1+ld",
            @"H78j4d4MaQhQVM9kkE1xbOkEUB5j+G2AEi3Q8HgwyDEZhsflhJ5MEEqDHo8jMj+PsM+LebcbuqYhl9HhmZlFhr/VqOwY8CYThE4D0loSWiREQMJJWBImRyPlmKHxQY9nHTDFsSmQOXoqz2QjXjM7wLxvZsqOED2o",
            @"JzXYr1mR4rER2RJQMuJGWV1dhUbjxQhJGOK9YlaM1hSUwIj6GLa1AFokojKoAqw5L5phVjXbvhkXnJYRTFvHMNY3hAKnlp1KXYAyOS9zrJWKC/QaQ4gGCkA+lamqTAE0MhlT5+W6xvGlPERPmYYnA/PrbVOzvE++",
            @"L1NJnKFqnp9zOmDp6cVY7yBG+4dw/fr1qkXbk7pD9Dq9ZnjMABLNKRgDQMJLZ7gqY2m0ZFPTkzmBpGpBf7VjagDZYaLSjgUCD50fHRxSHhzrG4aNWXYnUheglF66zGMc/I8CGm09GUeWoZrV08gQVM4pmCqc4UkJ",
            @"Yc6J1fuN35B7je+LyrwpyUcA46EQej/roBeHMXp1ELO2qW1PIXUBSj1Z4EQu2a12rGToJbOta5sDymfTk6IyRs0ktJkKoMDJNBJksrF09WC0h2F6dQBjPQNwWMZxp1rm1SN1AQpYQc8iGgyppCKGCJwJq6ujZpRj",
            @"zKYZmQLomSQ98BAcvSzhmmUHFGqgTJUxm5LKh4loymLFcGcPw7MfvRfbYenuQ2vLB7h05gzhnVXLtpa6APOES7CmzNSGEj1hto3MKR7jZ2osFESQ81qa96gOqV5LBnkuETW8WPNbpornxIMyH6bZSfaRMXSevUDA",
            @"DgXYR9Brvb2qo8sLpap1T5YtAWX8abEEvSXGG+NPMp6oaZgYZXpJPjsnJhDx+5FN8DvrgPRgJKgSkHw27xUVYDmKB5OcSrwul0pYfpcbVz/tgJVwAmjt6cf02Bju37uP8HywauGT5YmAssSRyVzXaKSWpRFmeD4Y",
            @"h6KS/SQxmJBejp9ENTwzLOPUXMl7MzIPSpjWAjL8c+y4TDyhOko6RmO1I4BxekqgBG6kk8euAUTnA8q2XFpXx61kSw/K8ifDDJqlkVkepZdrAQVEPJAIG+NTxlgiEFz3iqhUL+JxCcswi2ydiUdWHXJNfi9LTREw",
            @"zHlQ5lkBlTEulY8C7OrHSBc92D2ABFcmYO0h01Y9siVghYvUHA2SyiXk8RGS8x0B5Ril5/wMpwwNkiolJiD8rgCJ8WbIjnM+k8wp0EkWAAGOT511q3hJgHQFSegaDdOTEhlj3b2EE8BedJ27qNaOm1VXj5MtARcK",
            @"BY7BGPwzboRm51SWMz0jKr0sIIOX2o21YCRswPqrVQnPdZ3+SBXV8j3pHLlHeV4ysYBSJcEImIy7DMdulFEwzXJttLNbwYnahi1Vq+qXupKMiKTmuQm7ApTxZgKmozEEZ5yY/LRtfWwJhIyjGENOQnP41AnYujrX",
            @"7zHDV6CUJ6uAAuuyT7GzOjEzPskSbRA95y5g5HKPArQwXG9ss2TbEtAUS28/bP3DDzxT1TS9MdlzBddaT6qlUO01Uy+1HELH+29jeniIKwWvGodqVcGwNSFNwAzLwcunz8LaSSDqiNKruEYdH7iGAIeJrEHrlboB",
            @"Bzo6VeE7zsK31vg4s1rniaOIOywIz7oeuiYqScQ70I28cwS5yBzCnjme1wnxsUomaU7qRngyuaRkTKbQcapNAZpg4j05OunV7UrdgBNDIxi5agz2aPBBUZynF5yXPkElNIPUzCQy9KicT/I7Aqdz3vONW+C6eAbv",
            @"v7oHb730exz865sYOtGCOcs1Zt+wgpNFcHd7Oxzj4zh7qAUDnNyvnG5THhS4nguXlA3blboBZXW9WKlgkOXT5IgVflYbXqcT9u4rOPCXP+P7X/s6nv3BU0wKHdDpmZnhQUS8bgWZYNY8/6+38PoLv8Q3v/JVfPnz",
            @"X8A3vvglzLZ/jLBjXAFeokdP7HsH1uMHEbf1o+3Quzi57230c6K3iBev9KgHW/eqOaFeqRvQlCjTvIWePHbgEFw2G6Y7zuPH3/o2XvvNC/jDT3+GXzz9I+hBDzSfG/q8AzGvE0m/h5BOvPKrF7H/5VfwxvMv4pnv",
            @"fA8vP/dzFAIuuKftOPXePrS9+ToCp1oQvdKK0csX0XpwH84eO6ZCdYLjX+a/7cq2AUXmvT71zOTkK3/ClXf/hhN7X0XbsRbs/fVv8fxTT2NquB/ldFhpKRNGJR3Cgh7G/tfewO9+8gye/e4Psee5F3Bm72tY1OaR",
            @"mLwG6ycnYDl+GM4D+xBrP4OxzkvobD2tsniUZVk8EKr++/ZkR4DyUFeeXvv7u2B57+8It3/EIsCJI3v34vBLf8Rcfw8qqRA1iFJqXh0Fcqz9ImxHPsDo0YPoPNoCnYmnItc1P5LDlzHL8zMfHkB+dgyXObW4p4yk",
            @"oh4ms/7ciewI0BR93g/nR4cR7LyAUnIenqEe9v5p5N02LKbCVAELEMLQPLNoeqQLmaHLyPnsWIrP0YN+BVgIuVCK+dhmR/R0YNI6Co/TVf2nnUtDgNKz8ZF++M4cwVLEwUzqxHJ8Bkv0yqIWJGAIiwpwHmVCLMY9",
            @"WAm7sBIYx/WQHSsRF5aSXnx64hjsQ1cRmhpD3OfBCJdEItspyR4nDQGK3L19C2kb57iJXqyGpgnoJhyhkgHDgypEBdiP5Zgb1wUwaCOgDasxF/o+OwcrS7D5OQ/WdmGPomFAU4pzdqxG6RF6qUygEiHLDNsyQ1M+",
            @"L7It11ajs1gNOwg6DUdHKyyDw+oZa7lUrv4SPcfxZm6zNbox0zTAm8uLKHBaWGJWlKRSFhVIhqkAVnh+Kek3OsBjQ+CzTzDQcpC15Y3qLxiydneNq5csZjj+pCTzc1WRkafn2eyOQrZpgCK3VleYSOaRC8yizGmh",
            @"RK1wLJYIV2KIarPj8HWcg/PDFjhOHifg4Ufmtntr9xCLxGEbt7FGzcBum4TX40GMFdL/HNCUNdmY0bj244QfdU/Dax9D35HDsLHodp08SsAjcLJ+nTx+lCuQR/cfbjI8V5ZXVNVy+9YtddxpwtkVwI0iBg4cPAAX",
            @"oQTM1GkCjnMZVWD4LbAMk82cZst/BVCeYw4c3L8OOHnsA0yca8W8w45KvoBSsYBKpcwVfmMbLZvJrgPeuHED50+ewmTLfjiPH8IkwWIcUwv5IsMzy8WvBi0qq/w4z/vUSqSZsquAy0tLcNsn0fbOPzDT3Y6w24Mi",
            @"wWSrW1b/8kA5r+dU1sxldSwUFtTz1nIuW/2FxmXXAJfLJbW3UF4gUD6PElVAsmld7QwLpLxxIe1CLkfNVtt59Uym0OC+oCm7AliWPft8DmVCyYMmgUnHE+rxY7FggD2Ae1TlmkDKI41GpemAxZRsoWkcYw9AlLeq",
            @"hhcLOR6N9mZwtZpLZZBmpzQiTQVcXaxAT0QJmCSggFQBH9IHcLIltxHK1CzHZzqhwetwbms3aaM0FTAbC0NPJTjeOK/VerBG5bGDAEhbNlE2gsl18ZqMV2mHvVwQy9PsHUrTABcXFpjyI8jnMo9AiYrxkjVlr0Pa",
            @"ci4RiT0EJ16TZz/J6nkT1jays91dkaYBRoNB5b3ihtCsBcjR+FxNWGpMPGZb4KT2zCRTCHn8Cs70ttvhUmN4J9IUQHlBwCvvuGQ0ZdDjAGWfMcvEYX6WF4jkKGACKG0JTS0cWwc01TE5Vf237UlTAGftdvXoL18z",
            @"lz1OJQTNdjwaWx9v8llAFGh1/NVqOBBUhfd2pSmA9sEBtaFSD6B4y2wHuIovZo22CSLXizVg8h5cLmvcI5sz25WGAfP8Y9foKMcIe71OQMP4LMJ+1p6sYozPLNt4FA8LoJRupsq1Aj0rSysp/7YjDQP657xwXhum",
            @"8TSyDkB5NUuBJJNIyct7BBVVMAzNhwEzPCcqgOwYAso+ZVP3B58o/J/R/mH4WFAb9eTmULWqMbEkwlHEw2HDeIFQXjKmBHldxQxR4xoTkM7sKwmK35d2sVD/q10NAerMiKO9/Shm0liogTBCbnMVQ+W9UNfEJBLR",
            @"CAEMD8o18a4ByM8KnuCSdOg5lXjoSXkHJx6J1L1H0RBgxBuA0zpBg3TV62LcRqDN1OuY5ridgHtqSk0dampgcZ1gopLfUDDsNDkvUOpNDXamFOATwyNob23Dap17hA0BTg1aEJjx1A0mKkbLS7HeaQemrFblHVll",
            @"yFSjXhVTwLoKxSyPUvkkOZ1cbjuPf+7Zg3+/8QaCfn/Vgq0E+A9xmVok+/1y7gAAAABJRU5ErkJggg=="        ];
        NSString *encoded = [chunks componentsJoinedByString:@""];
        NSData *data = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
        if (data.length > 0) image = [UIImage imageWithData:data scale:2.0];
    });
    return image;
}