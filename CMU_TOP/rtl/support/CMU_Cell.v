// Extracted without functional changes from:
// D:\Codex\RTL\PUB\Cell.V
// Source SHA256: ABE92D012F51E47AF2C76C93205DC7DE52D4B0D83E8A26243F02B91C8435A2D7
// Only the CMU-used clock cells are archived in this project snapshot.

module clk_buf
(
    input                                   in                                             ,
    output                                  out
);

BUFG BUFG(.O (out),.I (in));

endmodule

module clk_gat
(
    input                                   in                                             ,
    input                                   en                                             ,
    output                                  out
);

BUFGCE BUFGCE(.O (out), .CE(en),.I (in));

endmodule
