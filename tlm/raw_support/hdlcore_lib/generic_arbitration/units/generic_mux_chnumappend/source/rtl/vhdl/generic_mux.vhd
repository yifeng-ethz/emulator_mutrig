library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.datapath_helpers.all;

entity generic_mux is
    generic (
        NPORTS        : natural := 4;
        IN_BUS_WIDTH  : natural := 78;
        OUT_BUS_WIDTH : natural := 78
    );
    port (
        i_ports : in  t_std_logic_matrix(NPORTS - 1 downto 0, IN_BUS_WIDTH - 1 downto 0);
        i_sel   : in  natural range NPORTS - 1 downto 0;
        o_port  : out std_logic_vector(OUT_BUS_WIDTH - 1 downto 0)
    );
end entity generic_mux;

architecture rtl of generic_mux is
begin
    process(all)
        variable row_v    : std_logic_vector(IN_BUS_WIDTH - 1 downto 0);
        variable result_v : std_logic_vector(OUT_BUS_WIDTH - 1 downto 0);
    begin
        row_v    := get_matrix_row(i_ports, i_sel);
        result_v := (others => '0');

        if OUT_BUS_WIDTH > IN_BUS_WIDTH then
            result_v(OUT_BUS_WIDTH - 1 downto IN_BUS_WIDTH) :=
                std_logic_vector(to_unsigned(i_sel, OUT_BUS_WIDTH - IN_BUS_WIDTH));
            result_v(IN_BUS_WIDTH - 1 downto 0) := row_v;
        elsif OUT_BUS_WIDTH = IN_BUS_WIDTH then
            result_v := row_v;
        else
            result_v := row_v(OUT_BUS_WIDTH - 1 downto 0);
        end if;

        o_port <= result_v;
    end process;
end architecture rtl;
