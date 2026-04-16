library ieee;
use ieee.std_logic_1164.all;

entity roundrobin_sel is
    generic (
        NPORTS : natural := 4
    );
    port (
        i_req       : in  std_logic_vector(NPORTS - 1 downto 0);
        i_priority  : in  natural range NPORTS - 1 downto 0;
        o_gnt_valid : out std_logic;
        o_gnt       : out natural range NPORTS - 1 downto 0
    );
end entity roundrobin_sel;

architecture rtl of roundrobin_sel is
begin
    process(all)
        variable found_v : boolean;
        variable idx_v   : natural range 0 to NPORTS - 1;
    begin
        found_v     := false;
        o_gnt       <= i_priority;
        o_gnt_valid <= '0';

        for offset in 0 to NPORTS - 1 loop
            idx_v := (i_priority + offset) mod NPORTS;
            if (not found_v) and (i_req(idx_v) = '1') then
                o_gnt       <= idx_v;
                o_gnt_valid <= '1';
                found_v     := true;
            end if;
        end loop;
    end process;
end architecture rtl;
