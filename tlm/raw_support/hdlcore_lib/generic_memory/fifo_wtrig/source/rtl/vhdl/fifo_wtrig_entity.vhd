library ieee;
use ieee.std_logic_1164.all;

entity fifo_wtrig is
    generic (
        C_DATA_WIDTH                : integer := 32;
        C_ADDR_WIDTH                : integer := 6;
        C_NUM_WORDS                 : integer := 64;
        C_NUM_TRIG_STEP_WIDTH       : integer := 4;
        C_TRIG_STEP_LENTH_CNT_WIDTH : integer := 4;
        C_TRIG_STEP_LENTH_CNT_MAX   : integer := 10
    );
    port (
        i_rst               : in  std_logic;
        clka                : in  std_logic;
        clkb                : in  std_logic;
        din                 : in  std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        we_a                : in  std_logic;
        re_b                : in  std_logic;
        dout                : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        count               : out std_logic_vector(C_ADDR_WIDTH - 1 downto 0);
        full                : out std_logic;
        empty               : out std_logic;
        data_rdy            : out std_logic;
        almost_full         : out std_logic;
        i_trigger           : in  std_logic;
        trig_mode           : in  std_logic;
        trig_back_time      : in  std_logic_vector(C_NUM_TRIG_STEP_WIDTH - 1 downto 0);
        trig_sign_forw_time : in  std_logic;
        trig_forw_time      : in  std_logic_vector(C_NUM_TRIG_STEP_WIDTH - 1 downto 0)
    );
end entity fifo_wtrig;
