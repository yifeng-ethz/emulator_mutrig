library ieee;
use ieee.std_logic_1164.all;

entity arb_selection_alter is
    generic (
        NPORTS : natural := 4
    );
    port (
        i_clk       : in  std_logic;
        i_rst       : in  std_logic;
        i_req       : in  std_logic_vector(NPORTS - 1 downto 0);
        o_gnt_valid : out std_logic;
        i_ack       : in  std_logic;
        o_gnt       : out natural range NPORTS - 1 downto 0
    );
end entity arb_selection_alter;

architecture roundrobin_alternant of arb_selection_alter is
    signal s_priority  : natural range NPORTS - 1 downto 0 := 0;
    signal s_gnt       : natural range NPORTS - 1 downto 0 := 0;
    signal s_gnt_valid : std_logic := '0';
begin
    process(all)
        variable found_v : boolean;
        variable idx_v   : natural range 0 to NPORTS - 1;
    begin
        found_v     := false;
        s_gnt       <= s_priority;
        s_gnt_valid <= '0';

        for offset in 0 to NPORTS - 1 loop
            idx_v := (s_priority + offset) mod NPORTS;
            if (not found_v) and (i_req(idx_v) = '1') then
                s_gnt       <= idx_v;
                s_gnt_valid <= '1';
                found_v     := true;
            end if;
        end loop;
    end process;

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_priority <= 0;
            elsif (i_ack = '1') and (s_gnt_valid = '1') then
                s_priority <= (s_gnt + 1) mod NPORTS;
            end if;
        end if;
    end process;

    o_gnt       <= s_gnt;
    o_gnt_valid <= s_gnt_valid;
end architecture roundrobin_alternant;
