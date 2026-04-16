library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture generic_ram of fifo_wtrig is
    type t_mem is array (0 to C_NUM_WORDS - 1) of std_logic_vector(C_DATA_WIDTH - 1 downto 0);

    signal s_mem           : t_mem;
    signal s_wr_ptr        : integer range 0 to C_NUM_WORDS - 1 := 0;
    signal s_rd_ptr        : integer range 0 to C_NUM_WORDS - 1 := 0;
    signal s_count         : integer range 0 to C_NUM_WORDS := 0;
    signal s_dout          : std_logic_vector(C_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_not_empty_dly : std_logic_vector(1 downto 0) := (others => '0');

    function sat_count(value : integer) return std_logic_vector is
        constant MAX_COUNT : integer := (2 ** C_ADDR_WIDTH) - 1;
    begin
        if value > MAX_COUNT then
            return std_logic_vector(to_unsigned(MAX_COUNT, C_ADDR_WIDTH));
        end if;
        return std_logic_vector(to_unsigned(value, C_ADDR_WIDTH));
    end function;

    function next_ptr(value : integer) return integer is
    begin
        if value = C_NUM_WORDS - 1 then
            return 0;
        end if;
        return value + 1;
    end function;

    function almost_full_level return integer is
    begin
        if C_NUM_WORDS > 3 then
            return C_NUM_WORDS - 3;
        end if;
        return C_NUM_WORDS;
    end function;
begin
    process(clka)
        variable write_ok_v   : boolean;
        variable read_ok_v    : boolean;
        variable next_count_v : integer range 0 to C_NUM_WORDS;
        variable not_empty_v  : std_logic;
    begin
        if rising_edge(clka) then
            if i_rst = '1' then
                s_wr_ptr        <= 0;
                s_rd_ptr        <= 0;
                s_count         <= 0;
                s_dout          <= (others => '0');
                s_not_empty_dly <= (others => '0');
            else
                write_ok_v := (we_a = '1') and (s_count < C_NUM_WORDS);
                read_ok_v  := (re_b = '1') and (s_count > 0);

                if write_ok_v then
                    s_mem(s_wr_ptr) <= din;
                    s_wr_ptr        <= next_ptr(s_wr_ptr);
                end if;

                if read_ok_v then
                    s_dout   <= s_mem(s_rd_ptr);
                    s_rd_ptr <= next_ptr(s_rd_ptr);
                end if;

                next_count_v := s_count;
                if write_ok_v and (not read_ok_v) then
                    next_count_v := s_count + 1;
                elsif read_ok_v and (not write_ok_v) then
                    next_count_v := s_count - 1;
                end if;

                if next_count_v > 0 then
                    not_empty_v := '1';
                else
                    not_empty_v := '0';
                end if;

                s_count         <= next_count_v;
                s_not_empty_dly <= s_not_empty_dly(0) & not_empty_v;
            end if;
        end if;
    end process;

    dout        <= s_dout;
    count       <= sat_count(s_count);
    full        <= '1' when s_count = C_NUM_WORDS else '0';
    empty       <= '1' when s_count = 0 else '0';
    data_rdy    <= s_not_empty_dly(1);
    almost_full <= '1' when s_count >= almost_full_level else '0';
end architecture generic_ram;
